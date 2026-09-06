'use strict';
require('dotenv').config();
const { Client } = require('pg');

const cfg = {
  host: process.env.DB_STORE_HOST || 'localhost',
  port: Number(process.env.DB_STORE_PORT || 5432),
  user: process.env.DB_STORE_USER || 'postgres',
  password: process.env.DB_STORE_PASSWORD || '',
  database: process.env.DB_STORE_NAME || 'JonkStore_Postgre',
};

const STMTS = [
  'CREATE EXTENSION IF NOT EXISTS "uuid-ossp"',
  `CREATE TABLE IF NOT EXISTS businesses (
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
  )`,
  `CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    firebase_uid TEXT UNIQUE NOT NULL,
    username TEXT UNIQUE,
    email TEXT UNIQUE NOT NULL,
    role_name TEXT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
  )`,
  `CREATE TABLE IF NOT EXISTS owner_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    phone TEXT,
    UNIQUE(user_id, business_id)
  )`,
  `CREATE TABLE IF NOT EXISTS roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    slug TEXT NOT NULL,
    is_system_role BOOLEAN DEFAULT FALSE,
    UNIQUE(business_id, slug)
  )`,
  `CREATE TABLE IF NOT EXISTS permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    slug TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    module TEXT NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS role_permissions (
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
  )`,
  `CREATE TABLE IF NOT EXISTS employees (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    user_id UUID UNIQUE REFERENCES users(id) ON DELETE SET NULL,
    role_id UUID,
    branch_id UUID,
    employee_code TEXT,
    first_name TEXT,
    last_name TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    version INTEGER DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
  )`,
];

(async () => {
  const client = new Client(cfg);
  try {
    await client.connect();
    console.log(`Connected to ${cfg.database}`);
    for (const sql of STMTS) {
      const name = (sql.match(/CREATE TABLE IF NOT EXISTS (\w+)/) || [])[1]
        || (sql.match(/CREATE EXTENSION IF NOT EXISTS "?([\w-]+)"?/) || [])[1]
        || 'statement';
      try {
        await client.query(sql);
        console.log(`  ensured ${name}`);
      } catch (e) {
        console.warn(`  skip ${name}: ${e.message.split('\n')[0]}`);
      }
    }
    const wanted = ['businesses', 'users', 'owner_profiles', 'employees', 'roles', 'permissions', 'role_permissions'];
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
