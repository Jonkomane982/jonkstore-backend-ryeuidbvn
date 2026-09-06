'use strict';

const environment = require('./environment');

function parseBoolean(value, fallback = false) {
  if (value === undefined || value === null || value === '') return fallback;
  const normalized = String(value).trim().toLowerCase();
  if (['true', '1', 'yes', 'on'].includes(normalized)) return true;
  if (['false', '0', 'no', 'off'].includes(normalized)) return false;
  return fallback;
}

function parseNumber(value, fallback) {
  const num = Number(value);
  return Number.isFinite(num) ? num : fallback;
}

/**
 * Extracts components from a connection string (URL) if provided.
 * Standard format: postgres://user:pass@host:port/db
 */
function parseUrl(url) {
  if (!url) return null;
  try {
    const parsed = new URL(url);
    return {
      user: parsed.username,
      password: parsed.password,
      host: parsed.hostname,
      port: parseNumber(parsed.port, 5432),
      name: parsed.pathname.split('/')[1],
    };
  } catch (e) {
    return null;
  }
}

const storeFromUrl = parseUrl(process.env.DB_STORE_URL);
const aiFromUrl = parseUrl(process.env.DB_AI_URL);

/**
 * Database configurations for both Operational (Store) and Analytical (AI) databases.
 * Supports individual environment variables or a full connection URL (Render style).
 */
const databaseConfig = Object.freeze({
  store: Object.freeze({
    host: process.env.DB_STORE_HOST || (storeFromUrl ? storeFromUrl.host : 'localhost'),
    port: parseNumber(process.env.DB_STORE_PORT, (storeFromUrl ? storeFromUrl.port : 5432)),
    name: process.env.DB_STORE_NAME || (storeFromUrl ? storeFromUrl.name : 'JonkStore_Postgre'),
    user: process.env.DB_STORE_USER || (storeFromUrl ? storeFromUrl.user : 'postgres'),
    password: process.env.DB_STORE_PASSWORD || (storeFromUrl ? storeFromUrl.password : ''),
    ssl: parseBoolean(process.env.DB_STORE_SSL, !!process.env.DB_STORE_URL),
    isConfigured: Boolean(process.env.DB_STORE_USER || process.env.DB_STORE_URL),
  }),
  ai: Object.freeze({
    host: process.env.DB_AI_HOST || (aiFromUrl ? aiFromUrl.host : 'localhost'),
    port: parseNumber(process.env.DB_AI_PORT, (aiFromUrl ? aiFromUrl.port : 5432)),
    name: process.env.DB_AI_NAME || (aiFromUrl ? aiFromUrl.name : 'JonkAI'),
    user: process.env.DB_AI_USER || (aiFromUrl ? aiFromUrl.user : 'postgres'),
    password: process.env.DB_AI_PASSWORD || (aiFromUrl ? aiFromUrl.password : ''),
    ssl: parseBoolean(process.env.DB_AI_SSL, !!process.env.DB_AI_URL),
    isConfigured: Boolean(process.env.DB_AI_USER || process.env.DB_AI_URL),
  }),
  pool: Object.freeze({
    min: 2,
    max: 20,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 5000,
  }),
});

module.exports = databaseConfig;
