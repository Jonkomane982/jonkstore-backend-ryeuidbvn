'use strict';

const { asyncHandler, generateOtp } = require('../utils/helpers');
const { firebaseAdminService } = require('../services/firebase.service');
const { emailService } = require('../services/email.service');
const aiPipeline = require('../services/ai-data-pipeline.service');
const authRepository = require('../repositories/auth.repository');
const otpRepository = require('../repositories/otp.repository');
const { AuthenticationError, ValidationError } = require('../utils/errors');
const environment = require('../config/environment');

/**
 * Controller for User Authentication and Identity Management.
 */
class AuthController {
  /**
   * Verified Google Sign-In / Firebase ID Token.
   */
  login = asyncHandler(async (req, res) => {
    const { idToken } = req.body;

    if (!idToken) {
      throw new AuthenticationError('ID Token is required', 'MISSING_TOKEN');
    }

    const decodedToken = await firebaseAdminService.verifyIdToken(idToken);
    const { uid, email, name } = decodedToken;

    if (!email || !decodedToken.email_verified) {
      throw new AuthenticationError('A verified email address is required', 'EMAIL_NOT_VERIFIED');
    }

    let user = await authRepository.findUserByFirebaseUid(uid);

    if (!user) {
      if (!environment.ownerEmail || email.toLowerCase() !== environment.ownerEmail) {
        throw new AuthenticationError('This account is not authorized to create an owner profile', 'OWNER_ACCOUNT_REQUIRED');
      }
      user = await authRepository.createUser({
        firebase_uid: uid,
        email: email,
        username: name,
        role_name: 'OWNER',
      });
    }

    await authRepository.updateLastLogin(user.id);

    res.status(200).json({
      success: true,
      message: 'Authentication successful',
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

  /**
   * Request an OTP for Owner Verification.
   */
  requestOwnerOtp = asyncHandler(async (req, res) => {
    const { email } = req.body;
    if (!email || email.toLowerCase() !== environment.ownerEmail) {
      throw new ValidationError('A valid owner email is required');
    }

    const otpCode = generateOtp();
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000); // 15 mins

    console.log(`\n[TEST] Verification code for ${email}: ${otpCode}\n`);

    await otpRepository.invalidatePreviousOtps(email, 'OWNER_VERIFICATION');
    await otpRepository.createOtp({
      email,
      otpCode,
      purpose: 'OWNER_VERIFICATION',
      expiresAt,
    });

    await emailService.sendOwnerOtp({
      to: email,
      otpCode,
      expiresAt,
    });

    res.status(200).json({
      success: true,
      message: 'Verification code sent to email',
    });
  });

  /**
   * Verify the OTP provided by the user.
   */
  verifyOwnerOtp = asyncHandler(async (req, res) => {
    const { email, otpCode } = req.body;
    if (!email || !otpCode) throw new ValidationError('Email and code are required');

    const otp = await otpRepository.findValidOtp(email, otpCode, 'OWNER_VERIFICATION');
    if (!otp) {
      throw new ValidationError('Invalid or expired verification code');
    }

    await otpRepository.markAsUsed(otp.id);

    res.status(200).json({
      success: true,
      message: 'Email verified successfully',
    });
  });

  /**
   * Final step: Setup the business for the authenticated user and mirror to JonkAI.
   */
  setupBusiness = asyncHandler(async (req, res) => {
    const { businessName, industry, ownerFullName } = req.body;

    if (!req.user || !req.user.id) {
      throw new AuthenticationError('Authentication required');
    }

    if (!businessName || !ownerFullName) {
      throw new ValidationError('Business name and owner full name are required');
    }

    // 1. Transactional Operational Setup
    const business = await authRepository.setupNewBusiness(req.user.id, {
      name: businessName,
      industry,
      ownerFullName
    });

    // 2. AI Analytical Mirroring (Non-blocking)
    // Mirrors the business creation to JonkAI Core.
    try {
      await aiPipeline.processSyncEvent('businesses', 'CREATE', business);
    } catch (err) {
      req.appLogger.error({ err }, 'Failed to mirror business to AI during setup');
    }

    res.status(201).json({
      success: true,
      message: 'Business setup successful',
      data: {
        business: {
          id: business.id,
          name: business.name,
          industry: business.industry
        }
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
