'use strict';
require('dotenv').config();
const { Client } = require('pg');
const fs = require('fs');
const path = require('path');

const cfg = {
  host: process.env.DB_STORE_HOST || 'localhost',
  port: Number(process.env.DB_STORE_PORT || 5432),
  user: process.env.DB_STORE_USER || 'postgres',
  password: process.env.DB_STORE_PASSWORD || '',
  database: 'postgres',
};

const DB_NAME = process.env.DB_STORE_NAME || 'JonkStore_Postgre';
const SCHEMA_FILE = path.resolve(__dirname, '..', 'JonkStore_Postgre.sql');

(async () => {
  let client = new Client(cfg);
  try {
    await client.connect();
    console.log(`Connected to server at ${cfg.host}:${cfg.port}/${cfg.database}`);

    const existsR = await client.query(
      "SELECT 1 FROM pg_database WHERE datname = $1",
      [DB_NAME]
    );
    if (existsR.rowCount === 0) {
      console.log(`Creating database ${DB_NAME}...`);
      await client.query(`CREATE DATABASE "${DB_NAME}"`);
      console.log(`Database ${DB_NAME} created`);
    } else {
      console.log(`Database ${DB_NAME} already exists`);
    }
    await client.end();

    client = new Client({ ...cfg, database: DB_NAME });
    await client.connect();
    console.log(`Connected to ${DB_NAME}`);

    await client.query('CREATE EXTENSION IF NOT EXISTS "uuid-ossp"');
    console.log('Extension uuid-ossp ensured');

    if (fs.existsSync(SCHEMA_FILE)) {
      console.log(`Applying schema file: ${path.basename(SCHEMA_FILE)}`);
      const sql = fs.readFileSync(SCHEMA_FILE, 'utf8');
      try {
        await client.query(sql);
        console.log('Schema applied OK');
      } catch (err) {
        console.warn('Schema applied with warnings (tables likely already exist):', err.message.split('\n')[0]);
      }
    } else {
      console.warn(`Schema file not found at ${SCHEMA_FILE} — skipping bulk apply, ensuring minimum tables`);
      await client.query(`
        CREATE TABLE IF NOT EXISTS businesses (
          id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
          name TEXT NOT NULL,
          tax_id TEXT,
          industry TEXT,
          address TEXT,
          phone TEXT,
          email TEXT,
          logo_url TEXT,
          currency_code TEXT DEFAULT 'ZAR',
          is_active BOOLEAN DEFAULT TRUE,
          created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
        )`);
      await client.query(`
        CREATE TABLE IF NOT EXISTS users (
          id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
          firebase_uid TEXT UNIQUE NOT NULL,
          username TEXT UNIQUE,
          email TEXT UNIQUE NOT NULL,
          role_name TEXT NOT NULL,
          is_active BOOLEAN DEFAULT TRUE,
          last_login_at TIMESTAMPTZ,
          created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
        )`);
      await client.query(`
        CREATE TABLE IF NOT EXISTS owner_profiles (
          user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
          business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
          full_name TEXT NOT NULL,
          phone TEXT,
          UNIQUE(user_id, business_id)
        )`);
      console.log('Minimum tables ensured');
    }

    const wanted = ['users', 'businesses', 'owner_profiles'];
    const r = await client.query(`
      SELECT table_name FROM information_schema.tables
       WHERE table_schema='public' AND table_name = ANY($1::text[])
    `, [wanted]);
    console.log('Identity tables present:', r.rows.map(x => x.table_name).join(', '));
    const u = await client.query('SELECT COUNT(*)::int AS n FROM users');
    const b = await client.query('SELECT COUNT(*)::int AS n FROM businesses');
    console.log(`users=${u.rows[0].n}, businesses=${b.rows[0].n}`);
    console.log('DONE');
  } catch (e) {
    console.error('FATAL:', e.message);
    process.exitCode = 1;
  } finally {
    try { await client.end(); } catch(_) {}
  }
})();
