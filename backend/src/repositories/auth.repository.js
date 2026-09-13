'use strict';

const { store: db } = require('../utils/db');
const { logger } = require('../utils/logger');

const VALID_ROLES = ['ADMIN', 'OWNER', 'MANAGER', 'CASHIER', 'STORE_ASSISTANT'];
const VALID_STATUSES = ['pending', 'active', 'suspended'];

/**
 * Handles persistence for User Identity, Businesses, and RBAC in JonkStore_Postgre.
 */
class AuthRepository {
  async ensureAccountStatusColumn() {
    try {
      await db.query(`
        ALTER TABLE users
        ADD COLUMN IF NOT EXISTS account_status TEXT NOT NULL DEFAULT 'active'
      `);
      await db.query(`
        DO $$ BEGIN
          ALTER TABLE users ADD CONSTRAINT users_account_status_check
          CHECK (account_status IN ('pending', 'active', 'suspended'));
        EXCEPTION WHEN duplicate_object THEN NULL; END $$;
      `);
    } catch (err) {
      logger.warn({ err }, 'AuthRepository: ensureAccountStatusColumn skipped or failed');
    }
  }

  async findUserByFirebaseUid(uid) {
    const query = `
      SELECT id, firebase_uid, email, username, role_name,
             is_active, account_status,
             last_login_at, created_at
      FROM users WHERE firebase_uid = $1
    `;
    const res = await db.query(query, [uid]);
    return res.rows[0];
  }

  async findUserByEmail(email) {
    const query = `
      SELECT id, firebase_uid, email, username, role_name,
             is_active, account_status,
             last_login_at, created_at
      FROM users WHERE email = $1
    `;
    const res = await db.query(query, [email]);
    return res.rows[0];
  }

  async findUserById(id) {
    const query = `
      SELECT id, firebase_uid, email, username, role_name,
             is_active, account_status,
             last_login_at, created_at
      FROM users WHERE id = $1
    `;
    const res = await db.query(query, [id]);
    return res.rows[0];
  }

  async listUsers({ page = 1, limit = 50, role, status, search } = {}) {
    const whereClauses = [];
    const params = [];
    let paramIdx = 1;

    if (role) {
      whereClauses.push(`role_name = $${paramIdx}`);
      params.push(role.toUpperCase());
      paramIdx++;
    }
    if (status) {
      whereClauses.push(`account_status = $${paramIdx}`);
      params.push(status.toLowerCase());
      paramIdx++;
    }
    if (search) {
      whereClauses.push(`(email ILIKE $${paramIdx} OR username ILIKE $${paramIdx})`);
      params.push(`%${search}%`);
      paramIdx++;
    }

    const whereSql = whereClauses.length ? `WHERE ${whereClauses.join(' AND ')}` : '';
    const offset = (page - 1) * limit;

    const countQuery = `SELECT COUNT(*)::int AS total FROM users ${whereSql}`;
    const countRes = await db.query(countQuery, params);
    const total = countRes.rows[0].total;

    const dataQuery = `
      SELECT id, firebase_uid, email, username, role_name,
             is_active, account_status,
             last_login_at, created_at
      FROM users ${whereSql}
      ORDER BY created_at DESC
      LIMIT $${paramIdx} OFFSET $${paramIdx + 1}
    `;
    const dataRes = await db.query(dataQuery, [...params, limit, offset]);

    return {
      items: dataRes.rows,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  async createUser(userData) {
    const role = (userData.role_name || 'CASHIER').toUpperCase();
    if (!VALID_ROLES.includes(role)) {
      throw new Error(`Invalid role: ${role}`);
    }
    const status = userData.account_status || (role === 'ADMIN' ? 'active' : 'pending');

    const query = `
      INSERT INTO users (firebase_uid, email, username, role_name, is_active, account_status)
      VALUES ($1, $2, $3, $4, $5, $6)
      RETURNING id, firebase_uid, email, username, role_name,
                is_active, account_status, last_login_at, created_at;
    `;
    const params = [
      userData.firebase_uid,
      userData.email.toLowerCase(),
      userData.username || userData.email.split('@')[0],
      role,
      status === 'active',
      status,
    ];
    const res = await db.query(query, params);
    return res.rows[0];
  }

  async updateLastLogin(userId) {
    const query = 'UPDATE users SET last_login_at = CURRENT_TIMESTAMP WHERE id = $1';
    return db.query(query, [userId]);
  }

  async updateUserStatus(userId, accountStatus) {
    const status = accountStatus.toLowerCase();
    if (!VALID_STATUSES.includes(status)) {
      throw new Error(`Invalid account_status: ${accountStatus}`);
    }
    const query = `
      UPDATE users
      SET account_status = $1,
          is_active = CASE WHEN $1 = 'active' THEN TRUE ELSE FALSE END
      WHERE id = $2
      RETURNING id, email, role_name, account_status, is_active;
    `;
    const res = await db.query(query, [status, userId]);
    return res.rows[0];
  }

  async updateUserRole(userId, roleName) {
    const role = roleName.toUpperCase();
    if (!VALID_ROLES.includes(role)) {
      throw new Error(`Invalid role: ${roleName}`);
    }
    const query = `
      UPDATE users SET role_name = $1 WHERE id = $2
      RETURNING id, email, role_name, account_status;
    `;
    const res = await db.query(query, [role, userId]);
    return res.rows[0];
  }

  async deleteUser(userId) {
    const query = 'DELETE FROM users WHERE id = $1 RETURNING id, email';
    const res = await db.query(query, [userId]);
    return res.rows[0];
  }

  async setupNewBusiness(ownerId, businessData) {
    const client = await db.getClient();
    try {
      await client.query('BEGIN');

      const businessQuery = `
        INSERT INTO businesses (name, industry)
        VALUES ($1, $2)
        RETURNING *;
      `;
      const businessRes = await client.query(businessQuery, [
        businessData.name,
        businessData.industry || null
      ]);
      const business = businessRes.rows[0];

      const ownerProfileQuery = `
        INSERT INTO owner_profiles (user_id, business_id, full_name)
        VALUES ($1, $2, $3)
        RETURNING *;
      `;
      await client.query(ownerProfileQuery, [
        ownerId,
        business.id,
        businessData.ownerFullName
      ]);

      await client.query('COMMIT');
      return business;
    } catch (err) {
      await client.query('ROLLBACK');
      logger.error({ err }, 'AuthRepository: Failed to setup new business');
      throw err;
    } finally {
      client.release();
    }
  }
}

module.exports = new AuthRepository();
