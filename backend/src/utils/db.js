'use strict';

const { Pool } = require('pg');
const databaseConfig = require('../config/database');
const { logger } = require('./logger');

/**
 * Creates a PostgreSQL pool based on the provided configuration.
 */
function createPool(config, label) {
  const pool = new Pool({
    host: config.host,
    port: config.port,
    database: config.name,
    user: config.user,
    password: config.password,
    ssl: config.ssl ? { rejectUnauthorized: false } : false,
    max: databaseConfig.pool.max,
    idleTimeoutMillis: databaseConfig.pool.idleTimeoutMillis,
    connectionTimeoutMillis: databaseConfig.pool.connectionTimeoutMillis,
  });

  pool.on('connect', (client) => {
    logger.debug(`New client connected to PostgreSQL ${label} Database`);
  });

  pool.on('error', (err) => {
    logger.error({ err, label }, `PostgreSQL Pool Error: ${label}`);
  });

  return pool;
}

// Operational Store Database Pool
const storePool = createPool(databaseConfig.store, 'Store');

// Analytical AI Database Pool
const aiPool = createPool(databaseConfig.ai, 'AI');

module.exports = {
  // Operational Store
  store: {
    query: (text, params) => storePool.query(text, params),
    getClient: () => storePool.connect(),
    pool: storePool,
    /**
     * Sets the business_id for Row Level Security in the current transaction.
     */
    setTenantContext: async (client, businessId) => {
      await client.query('SELECT set_config($1, $2, true)', ['app.current_business_id', businessId]);
    },
    /**
     * Executes a callback within a transaction, automatically setting the tenant context.
     */
    transaction: async (businessId, callback) => {
      const client = await storePool.connect();
      try {
        await client.query('BEGIN');
        if (businessId) {
          await client.query('SELECT set_config($1, $2, true)', ['app.current_business_id', businessId]);
        }
        const result = await callback(client);
        await client.query('COMMIT');
        return result;
      } catch (err) {
        await client.query('ROLLBACK');
        throw err;
      } finally {
        client.release();
      }
    }
  },
  // Analytical AI
  ai: {
    query: (text, params) => aiPool.query(text, params),
    getClient: () => aiPool.connect(),
    pool: aiPool,
  },
};
