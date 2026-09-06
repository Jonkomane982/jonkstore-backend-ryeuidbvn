'use strict';

const { store: db } = require('../utils/db');
const authRepository = require('../repositories/auth.repository');

/**
 * Middleware to resolve the tenant (business_id) for the authenticated user.
 * It sets the app.current_business_id session variable in PostgreSQL for RLS.
 */
async function resolveTenantContext(req, res, next) {
  // Authentication must happen before tenant resolution
  if (!req.user || !req.user.uid) {
    return next();
  }

  try {
    // 1. Find user in Postgres by Firebase UID
    const user = await authRepository.findUserByFirebaseUid(req.user.uid);
    if (!user) {
      // User authenticated in Firebase but not registered in JonkStore yet
      return next();
    }

    // Always attach internal user details to req.user if found in JonkStore_Postgre
    req.user.id = user.id;
    req.user.role = user.role_name;

    // 2. Determine Business ID
    let businessId = null;

    // Check if they are an Owner first
    const business = await authRepository.getBusinessByOwnerEmail(user.email);
    if (business) {
      businessId = business.id;
    } else {
      // Check if they are an Employee
      const query = 'SELECT business_id FROM employees WHERE user_id = $1 AND is_deleted = FALSE';
      const result = await db.query(query, [user.id]);
      if (result.rows[0]) {
        businessId = result.rows[0].business_id;
      }
    }

    if (businessId) {
      req.businessId = businessId;
      // Note: RLS context is set inside db.store.transaction() or manually in specific repositories.
    }

    next();
  } catch (err) {
    next(err);
  }
}

module.exports = {
  resolveTenantContext,
};
