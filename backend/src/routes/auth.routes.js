'use strict';

const express = require('express');
const authController = require('../controllers/auth.controller');
const { requireAuthentication } = require('../middleware/auth.middleware');
const { firebaseAdminService } = require('../services/firebase.service');
const { validate } = require('../middleware/validation.middleware');
const { ownerForgotPasswordSchema } = require('../validators/common.validators');

/**
 * Routes for Authentication and Identity.
 */
function buildAuthRouter() {
  const router = express.Router();
  const auth = requireAuthentication(firebaseAdminService);

  // Primary Login Endpoint (Handles Google ID Tokens)
  router.post('/login', authController.login);

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

  return router;
}

module.exports = { buildAuthRouter };
