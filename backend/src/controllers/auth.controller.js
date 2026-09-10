'use strict';

const { asyncHandler, generateOtp } = require('../utils/helpers');
const { firebaseAdminService } = require('../services/firebase.service');
const { emailService } = require('../services/email.service');
const authRepository = require('../repositories/auth.repository');
const otpRepository = require('../repositories/otp.repository');
const { AuthenticationError, ValidationError, AuthorizationError, NotFoundError } = require('../utils/errors');
const environment = require('../config/environment');

/**
 * Permissions Map defining what each role can do.
 */
const ROLE_PERMISSIONS_MAP = {
  ADMIN: [
    'viewDashboard', 'manageProducts', 'manageCategories',
    'manageInventory', 'viewInventory', 'adjustInventory',
    'performStockCount', 'transferStock', 'viewInventoryCost',
    'manageSales', 'manageCustomers', 'manageSuppliers', 'managePurchases',
    'manageReports', 'manageNotifications', 'manageEmployees', 'manageSettings',
    'viewProfit', 'useAi', 'manageUsers',
  ],
  CASHIER: [
    'viewDashboard', 'manageSales', 'manageCustomers', 'manageNotifications',
  ],
};

function normalizeUserResponse(user) {
  if (!user) return null;
  return {
    id: user.id,
    email: user.email,
    username: user.username,
    role: user.role_name,
    accountStatus: user.account_status || 'pending',
    isActive: user.is_active,
    lastLoginAt: user.last_login_at,
    createdAt: user.created_at,
  };
}

class AuthController {
  /**
   * Universal Login: Allows any verified Firebase user.
   * Super Admin is auto-activated; others stay in pending until Admin approval.
   * Every login attempt triggers an OTP to the Super Admin email.
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
    if (!email) throw new AuthenticationError('Token missing email claim', 'TOKEN_MISSING_EMAIL');

    const loginEmail = email.toLowerCase();
    const adminEmail = (environment.ownerEmail || 'jonkomanelesoetsa@gmail.com').toLowerCase();
    const isSuperAdmin = loginEmail === adminEmail;

    let user = await authRepository.findUserByFirebaseUid(uid);

    if (!user) {
      // Auto-create account for any new user as a pending Cashier
      user = await authRepository.createUser({
        firebase_uid: uid,
        email: loginEmail,
        username: name || email.split('@')[0],
        role_name: isSuperAdmin ? 'ADMIN' : 'CASHIER',
        account_status: isSuperAdmin ? 'active' : 'pending',
      });
    } else if (isSuperAdmin) {
      // Force ensure Super Admin is always Admin and Active
      if (user.role_name !== 'ADMIN' || user.account_status !== 'active') {
        await authRepository.updateUserRole(user.id, 'ADMIN');
        await authRepository.updateUserStatus(user.id, 'active');
        user = await authRepository.findUserById(user.id);
      }
    }

    const status = user.account_status || 'pending';

    if (status === 'suspended') {
      throw new AuthenticationError('Your account has been suspended. Please contact the administrator.', 'ACCOUNT_SUSPENDED');
    }

    if (status === 'pending' && !isSuperAdmin) {
      return res.status(200).json({
        success: true,
        message: 'Account pending activation. Please wait for an Admin to approve your access.',
        data: {
          user: normalizeUserResponse(user),
          isPending: true
        }
      });
    }

    await authRepository.updateLastLogin(user.id);

    // GATEKEEPER: Trigger OTP to Super Admin for EVERY login session
    const otpCode = generateOtp();
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000);

    // Always send the authorization code to the Super Admin email.
    await otpRepository.invalidatePreviousOtps(adminEmail, 'LOGIN_AUTHORIZATION');
    await otpRepository.createOtp({
      email: adminEmail,
      otpCode,
      purpose: 'LOGIN_AUTHORIZATION',
      expiresAt,
    });

    await emailService.sendOwnerOtp({
      to: adminEmail,
      otpCode,
      expiresAt,
      businessName: 'JonkStore POS'
    });

    res.status(200).json({
      success: true,
      message: 'Password verified. Authorization code sent to the Super Admin.',
      data: {
        user: normalizeUserResponse(user),
        requiresOtp: true,
      }
    });
  });

  /**
   * Finalizes login after Admin provides the 6-digit code.
   */
  verifyLoginOtp = asyncHandler(async (req, res) => {
    const { otpCode } = req.body;
    const adminEmail = (environment.ownerEmail || 'jonkomanelesoetsa@gmail.com').toLowerCase();

    const otp = await otpRepository.findValidOtp(adminEmail, otpCode, 'LOGIN_AUTHORIZATION');
    if (!otp) {
      throw new AuthenticationError('Invalid or expired authorization code');
    }

    await otpRepository.markAsUsed(otp.id);

    // Identity confirmed via Admin code
    res.status(200).json({
      success: true,
      message: 'Identity verified',
    });
  });

  /**
   * Public registration endpoint.
   */
  register = asyncHandler(async (req, res) => {
    const { idToken, username } = req.body;
    if (!idToken) throw new ValidationError('idToken is required');

    let decodedToken;
    try {
      decodedToken = await firebaseAdminService.verifyIdToken(idToken);
    } catch (err) {
      throw new AuthenticationError('Invalid authentication token', 'INVALID_TOKEN');
    }

    const { uid, email } = decodedToken;
    const registerEmail = email.toLowerCase();
    const adminEmail = (environment.ownerEmail || 'jonkomanelesoetsa@gmail.com').toLowerCase();
    const isSuperAdmin = registerEmail === adminEmail;

    let user = await authRepository.findUserByEmail(registerEmail);

    if (!user) {
      user = await authRepository.createUser({
        firebase_uid: uid,
        email: registerEmail,
        username: username || registerEmail.split('@')[0],
        role_name: isSuperAdmin ? 'ADMIN' : 'CASHIER',
        account_status: isSuperAdmin ? 'active' : 'pending',
      });
    }

    res.status(201).json({
      success: true,
      message: isSuperAdmin ? 'Admin account created.' : 'Registration successful. Account pending admin activation.',
      data: { user: normalizeUserResponse(user) }
    });
  });

  /**
   * ADMIN ONLY: List all users registered in the system.
   */
  listUsers = asyncHandler(async (req, res) => {
    if (req.user.role !== 'ADMIN') throw new AuthorizationError('Admin access required');
    const result = await authRepository.listUsers(req.query);
    res.status(200).json({
      success: true,
      data: {
        items: result.items.map(normalizeUserResponse),
        pagination: result.pagination,
      }
    });
  });

  /**
   * ADMIN ONLY: Update User Status (Activate/Suspend).
   */
  updateUserStatus = asyncHandler(async (req, res) => {
    if (req.user.role !== 'ADMIN') throw new AuthorizationError('Admin access required');
    const { id } = req.params;
    const { status } = req.body; // 'active', 'suspended', 'pending'

    const target = await authRepository.findUserById(id);
    if (!target) throw new NotFoundError('User not found');

    if (target.email === (environment.ownerEmail || 'jonkomanelesoetsa@gmail.com').toLowerCase()) {
      throw new ValidationError('Cannot modify status of the Super Admin');
    }

    const updated = await authRepository.updateUserStatus(id, status.toLowerCase());
    res.status(200).json({
      success: true,
      message: `User status set to ${status}`,
      data: normalizeUserResponse(updated),
    });
  });

  /**
   * ADMIN ONLY: Delete User.
   */
  deleteUser = asyncHandler(async (req, res) => {
    if (req.user.role !== 'ADMIN') throw new AuthorizationError('Admin access required');
    const { id } = req.params;
    const target = await authRepository.findUserById(id);
    if (!target || target.email === (environment.ownerEmail || 'jonkomanelesoetsa@gmail.com')) {
      throw new ValidationError('The Super Admin account cannot be deleted');
    }
    await authRepository.deleteUser(id);
    res.status(200).json({ success: true, message: 'Account deleted' });
  });

  /**
   * Account Recovery: Sends Firebase password reset link via custom SMTP.
   */
  requestPasswordReset = asyncHandler(async (req, res) => {
    const { email } = req.body;
    if (!email) throw new ValidationError('Email is required');

    try {
      const link = await firebaseAdminService.generatePasswordResetLink(email.toLowerCase());
      await emailService.sendPasswordResetEmail({ to: email.toLowerCase(), link });
    } catch (err) {
      // Mask failure to prevent email discovery
      req.appLogger.debug({ err, email }, 'Recovery request for unknown email');
    }

    res.status(200).json({
      success: true,
      message: 'If the account exists, a recovery link has been sent.',
    });
  });

  me = asyncHandler(async (req, res) => {
    const user = await authRepository.findUserById(req.user.id);
    res.status(200).json({
      success: true,
      data: {
        user: normalizeUserResponse(user),
        permissions: ROLE_PERMISSIONS_MAP[user.role_name] || [],
      }
    });
  });
}

module.exports = new AuthController();
