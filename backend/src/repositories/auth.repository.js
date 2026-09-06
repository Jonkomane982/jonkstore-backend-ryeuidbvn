'use strict';

const { store: db } = require('../utils/db');
const { logger } = require('../utils/logger');

/**
 * Handles persistence for User Identity, Businesses, and RBAC in JonkStore_Postgre.
 */
class AuthRepository {
  async findUserByFirebaseUid(uid) {
    const query = 'SELECT * FROM users WHERE firebase_uid = $1';
    const res = await db.query(query, [uid]);
    return res.rows[0];
  }

  async findUserByEmail(email) {
    const query = 'SELECT * FROM users WHERE email = $1';
    const res = await db.query(query, [email]);
    return res.rows[0];
  }

  async createUser(userData) {
    const query = `
      INSERT INTO users (firebase_uid, email, username, role_name, is_active)
      VALUES ($1, $2, $3, $4, $5)
      RETURNING *;
    `;
    const params = [
      userData.firebase_uid,
      userData.email,
      userData.username || userData.email.split('@')[0],
      userData.role_name || 'CASHIER',
      true
    ];
    const res = await db.query(query, params);
    return res.rows[0];
  }

  async updateLastLogin(userId) {
    const query = 'UPDATE users SET last_login_at = CURRENT_TIMESTAMP WHERE id = $1';
    return db.query(query, [userId]);
  }

  async getBusinessByOwnerEmail(email) {
    const query = `
      SELECT b.* FROM businesses b
      JOIN owner_profiles op ON b.id = op.business_id
      JOIN users u ON op.user_id = u.id
      WHERE u.email = $1
    `;
    const res = await db.query(query, [email]);
    return res.rows[0];
  }

  /**
   * Creates a new business and links it to an owner profile.
   * Atomic operation recommended to be called within a transaction context if needed,
   * but here we provide the individual steps.
   */
  async setupNewBusiness(ownerId, businessData) {
    const client = await db.getClient();
    try {
      await client.query('BEGIN');

      // 1. Create Business
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

      // 2. Create Owner Profile
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

      // 3. Update User Role to OWNER if not already
      await client.query('UPDATE users SET role_name = $1 WHERE id = $2', ['OWNER', ownerId]);

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
