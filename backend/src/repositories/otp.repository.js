'use strict';

const { store: db } = require('../utils/db');
const { logger } = require('../utils/logger');

/**
 * Repository for managing temporary One-Time Passwords (OTPs).
 */
class OtpRepository {
  async createOtp({ email, otpCode, purpose, expiresAt }) {
    const query = `
      INSERT INTO otps (email, otp_code, purpose, expires_at)
      VALUES ($1, $2, $3, $4)
      RETURNING *;
    `;
    const params = [email, otpCode, purpose, expiresAt];
    const res = await db.query(query, params);
    return res.rows[0];
  }

  async findValidOtp(email, otpCode, purpose) {
    const query = `
      SELECT * FROM otps
      WHERE email = $1
        AND otp_code = $2
        AND purpose = $3
        AND is_used = FALSE
        AND expires_at > CURRENT_TIMESTAMP
      ORDER BY created_at DESC
      LIMIT 1;
    `;
    const res = await db.query(query, [email, otpCode, purpose]);
    return res.rows[0];
  }

  async markAsUsed(otpId) {
    const query = 'UPDATE otps SET is_used = TRUE, verified_at = CURRENT_TIMESTAMP WHERE id = $1';
    return db.query(query, [otpId]);
  }

  async invalidatePreviousOtps(email, purpose) {
    const query = 'UPDATE otps SET is_used = TRUE WHERE email = $1 AND purpose = $2 AND is_used = FALSE';
    return db.query(query, [email, purpose]);
  }
}

module.exports = new OtpRepository();
