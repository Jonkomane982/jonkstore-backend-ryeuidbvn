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
 */
class AuthController {
  /**
   * Syncs Firebase authenticated user with the local database.
   */
  login = asyncHandler(async (req, res) => {
    const { idToken } = req.body;
    if (!idToken) throw new AuthenticationError('Authentication failed', 'MISSING_TOKEN');

    let decodedToken;
    try {
      decodedToken = await firebaseAdminService.verifyIdToken(idToken);
    } catch (err) {
      throw new AuthenticationError('Authentication failed', 'INVALID_TOKEN');
    }

    const { uid, email, name } = decodedToken;
    const loginEmail = email.toLowerCase();
    const authorizedEmail = (environment.ownerEmail || '').toLowerCase();

    // SECURITY: Ensure only the authorized owner can access
    const isAuthorizedOwner = authorizedEmail && loginEmail === authorizedEmail;

    let user = await authRepository.findUserByFirebaseUid(uid);

    if (!user) {
      if (!isAuthorizedOwner) {
        throw new AuthenticationError('Access denied. This account is not authorized.', 'OWNER_ACCOUNT_REQUIRED');
      }
      user = await authRepository.createUser({
        firebase_uid: uid,
        email: loginEmail,
        username: name || email.split('@')[0],
        role_name: 'OWNER',
      });
    }

    await authRepository.updateLastLogin(user.id);

    res.status(200).json({
      success: true,
      message: 'Access granted',
      data: {
        user: { id: user.id, email: user.email, username: user.username, role: user.role_name }
      }
    });
  });

  /**
   * Triggers a 6-digit OTP for Owner Login/Setup verification.
   */
  requestOwnerOtp = asyncHandler(async (req, res) => {
    const { email } = req.body;
    const authorizedEmail = (environment.ownerEmail || '').toLowerCase();

    if (email && email.toLowerCase() === authorizedEmail) {
      const otpCode = generateOtp();
      const expiresAt = new Date(Date.now() + 15 * 60 * 1000);

      await otpRepository.invalidatePreviousOtps(email, 'OWNER_VERIFICATION');
      await otpRepository.createOtp({ email: email.toLowerCase(), otpCode, purpose: 'OWNER_VERIFICATION', expiresAt });
      await emailService.sendOwnerOtp({ to: email.toLowerCase(), otpCode, expiresAt });
    }

    res.status(200).json({
      success: true,
      message: 'If authorized, a verification code has been sent to your email.',
    });
  });

  /**
   * Generates and sends a Firebase Password Reset link via SMTP.
   */
  requestOwnerPasswordReset = asyncHandler(async (req, res) => {
    const { email } = req.body;
    const authorizedEmail = (environment.ownerEmail || '').toLowerCase();

    if (email && email.toLowerCase() === authorizedEmail) {
      const link = await firebaseAdminService.generatePasswordResetLink(email.toLowerCase());
      await emailService.sendPasswordResetEmail({ to: email.toLowerCase(), link });
    }

    res.status(200).json({
      success: true,
      message: 'If authorized, a recovery link has been sent to your email.',
    });
  });

  verifyOwnerOtp = asyncHandler(async (req, res) => {
    const { email, otpCode } = req.body;
    const otp = await otpRepository.findValidOtp(email.toLowerCase(), otpCode, 'OWNER_VERIFICATION');
    if (!otp) throw new AuthenticationError('Invalid or expired verification code');
    await otpRepository.markAsUsed(otp.id);
    res.status(200).json({ success: true, message: 'Identity verified' });
  });

  setupBusiness = asyncHandler(async (req, res) => {
    const { businessName, industry, ownerFullName } = req.body;
    if (!req.user) throw new AuthenticationError('Session expired');
    const business = await authRepository.setupNewBusiness(req.user.id, { name: businessName, industry, ownerFullName });
    res.status(201).json({ success: true, message: 'Setup complete', data: { business } });
  });

  me = asyncHandler(async (req, res) => {
    res.status(200).json({ success: true, data: { user: req.user } });
  });
}

module.exports = new AuthController();
