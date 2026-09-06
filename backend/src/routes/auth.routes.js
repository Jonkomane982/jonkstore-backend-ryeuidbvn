'use strict';

const express = require('express');
const authController = require('../controllers/auth.controller');
const { requireAuthentication } = require('../middleware/auth.middleware');
const { firebaseAdminService } = require('../services/firebase.service');

/**
 * Routes for Authentication and Identity.
 */
function buildAuthRouter() {
  const router = express.Router();
  const auth = requireAuthentication(firebaseAdminService);

  // Primary Login Endpoint (Handles Google ID Tokens)
  router.post('/login', authController.login);

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
