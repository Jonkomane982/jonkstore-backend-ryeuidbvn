'use strict';

const express = require('express');
const authController = require('../controllers/auth.controller');
const {
  requireAuthentication,
  requireRole,
  requirePermission,
} = require('../middleware/auth.middleware');
const { firebaseAdminService } = require('../services/firebase.service');
const { validate } = require('../middleware/validation.middleware');
const {
  ownerForgotPasswordSchema,
  authRegisterSchema,
  authLoginSchema,
  userListQuerySchema,
  idParamSchema,
  userStatusSchema,
  userRoleSchema,
} = require('../validators/common.validators');

/**
 * Routes for Authentication and Identity.
 */
function buildAuthRouter() {
  const router = express.Router();
  const auth = requireAuthentication(firebaseAdminService);
  const requireAdmin = [auth, requireRole('ADMIN', 'OWNER')];

  // Primary Login Endpoint (Handles Google ID Tokens)
  router.post('/login', validate({ body: authLoginSchema }), authController.login);

  // Public Registration Endpoint — any verified Firebase user can register
  router.post('/register', validate({ body: authRegisterSchema }), authController.register);

  // Owner Forgot Password — unauthenticated endpoint, sends password reset link via SMTP
  router.post(
    '/owner/forgot-password',
    validate(ownerForgotPasswordSchema),
    authController.requestOwnerPasswordReset
  );

  // Protected Identity Routes
  router.get('/me', auth, authController.me);

  // OTP Verification for Owner Setup
  router.post('/owner/request-otp', authController.requestOwnerOtp);
  router.post('/owner/verify-otp', authController.verifyOwnerOtp);

  // Final Business Setup (requires verified token)
  router.post('/setup-business', auth, authController.setupBusiness);

  // Session Management
  router.post('/logout', auth, (req, res) => res.status(200).json({ success: true }));

  // --- Admin / User Management Endpoints ---
  // List all users (ADMIN / OWNER only)
  router.get(
    '/users',
    requireAdmin,
    validate({ query: userListQuerySchema }),
    authController.listUsers
  );

  // Get single user (ADMIN / OWNER, or self)
  router.get(
    '/users/:id',
    auth,
    validate({ params: idParamSchema }),
    authController.getUser
  );

  // Update user account status (ADMIN / OWNER only)
  router.patch(
    '/users/:id/status',
    requireAdmin,
    validate({ params: idParamSchema, body: userStatusSchema }),
    authController.updateUserStatus
  );

  // Update user role (ADMIN / OWNER only)
  router.patch(
    '/users/:id/role',
    requireAdmin,
    validate({ params: idParamSchema, body: userRoleSchema }),
    authController.updateUserRole
  );

  // Delete a user (ADMIN / OWNER only)
  router.delete(
    '/users/:id',
    requireAdmin,
    validate({ params: idParamSchema }),
    authController.deleteUser
  );

  return router;
}

module.exports = { buildAuthRouter };
