'use strict';

const { asyncHandler, generateOtp } = require('../utils/helpers');
const { firebaseAdminService } = require('../services/firebase.service');
const { emailService } = require('../services/email.service');
const authRepository = require('../repositories/auth.repository');
const otpRepository = require('../repositories/otp.repository');
const { AuthenticationError, ValidationError } = require('../utils/errors');
const environment = require('../config/environment');

/**
 * Controller for User Authentication.
 * Hardened with generic error messages to prevent account enumeration.
 */
class AuthController {
  login = asyncHandler(async (req, res) => {
    const { idToken } = req.body;

    if (!idToken) {
      throw new AuthenticationError('Authentication failed', 'MISSING_TOKEN');
    }

    let decodedToken;
    try {
      decodedToken = await firebaseAdminService.verifyIdToken(idToken);
    } catch (err) {
      req.appLogger.error({ err }, 'Firebase token verification failed');
      throw new AuthenticationError('Authentication failed', 'INVALID_TOKEN');
    }

    const { uid, email, name } = decodedToken;

    if (!email) {
      throw new AuthenticationError('Authentication failed', 'EMAIL_REQUIRED');
    }

    // SECURITY: Ensure only the authorized owner can log in/setup
    const isAuthorizedOwner = environment.ownerEmail &&
                             email.toLowerCase() === environment.ownerEmail.toLowerCase();

    let user = await authRepository.findUserByFirebaseUid(uid);

    if (!user) {
      if (!isAuthorizedOwner) {
        req.appLogger.warn({ email }, 'Unauthorized login attempt blocked');
        throw new AuthenticationError('Access denied', 'OWNER_ACCOUNT_REQUIRED');
      }

      user = await authRepository.createUser({
        firebase_uid: uid,
        email: email.toLowerCase(),
        username: name || email.split('@')[0],
        role_name: 'OWNER',
      });
    }

    await authRepository.updateLastLogin(user.id);

    res.status(200).json({
      success: true,
      message: 'Access granted',
      data: {
        user: {
          id: user.id,
          email: user.email,
          role: user.role_name,
          username: user.username,
        }
      }
    });
  });

  requestOwnerOtp = asyncHandler(async (req, res) => {
    const { email } = req.body;

    // Masking: Always return success even if email doesn't match OWNER_EMAIL
    // to prevent email discovery, but only send if it matches.
    if (email && environment.ownerEmail && email.toLowerCase() === environment.ownerEmail.toLowerCase()) {
      const otpCode = generateOtp();
      const expiresAt = new Date(Date.now() + 15 * 60 * 1000);

      await otpRepository.invalidatePreviousOtps(email, 'OWNER_VERIFICATION');
      await otpRepository.createOtp({
        email: email.toLowerCase(),
        otpCode,
        purpose: 'OWNER_VERIFICATION',
        expiresAt,
      });

      await emailService.sendOwnerOtp({
        to: email.toLowerCase(),
        otpCode,
        expiresAt,
      });

      req.appLogger.info({ email }, 'Verification code dispatched to authorized owner');
    }

    res.status(200).json({
      success: true,
      message: 'If authorized, a verification code has been sent to your email.',
    });
  });

  verifyOwnerOtp = asyncHandler(async (req, res) => {
    const { email, otpCode } = req.body;
    if (!email || !otpCode) throw new ValidationError('Credentials required');

    const otp = await otpRepository.findValidOtp(email.toLowerCase(), otpCode, 'OWNER_VERIFICATION');
    if (!otp) {
      // Generic error
      throw new AuthenticationError('Invalid verification code');
    }

    await otpRepository.markAsUsed(otp.id);

    res.status(200).json({
      success: true,
      message: 'Identity verified',
    });
  });

  requestOwnerPasswordReset = asyncHandler(async (req, res) => {
    const { email } = req.body;
    const firebase = req.services && req.services.firebase ? req.services.firebase : firebaseAdminService;
    const emailSvc = req.services && req.services.email ? req.services.email : emailService;

    if (
      email &&
      environment.ownerEmail &&
      email.toLowerCase() === environment.ownerEmail.toLowerCase()
    ) {
      const normalizedEmail = email.toLowerCase();
      const link = await firebase.generatePasswordResetLink(normalizedEmail);
      await emailSvc.sendPasswordResetEmail({ to: normalizedEmail, link });
      req.appLogger.info({ email: normalizedEmail }, 'Password reset link dispatched to authorized owner');
    }

    res.status(200).json({
      success: true,
      message: 'If authorized, a password reset link has been sent to your email.',
    });
  });

  setupBusiness = asyncHandler(async (req, res) => {
    const { businessName, industry, ownerFullName } = req.body;

    if (!req.user || !req.user.id) {
      throw new AuthenticationError('Session expired');
    }

    if (!businessName || !ownerFullName) {
      throw new ValidationError('All fields are required');
    }

    const business = await authRepository.setupNewBusiness(req.user.id, {
      name: businessName,
      industry,
      ownerFullName
    });

    res.status(201).json({
      success: true,
      message: 'Business setup successful',
      data: {
        business: { id: business.id, name: business.name }
      }
    });
  });

  me = asyncHandler(async (req, res) => {
    res.status(200).json({
      success: true,
      data: { user: req.user }
    });
  });
}

module.exports = new AuthController();
