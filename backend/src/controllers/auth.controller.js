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
 * Super Admin (ADMIN) has full access, including User Management.
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

function isAdminRole(role) {
  return role === 'ADMIN' || role === 'OWNER';
}

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
   * Universal Login: Allows any verified Firebase user to enter.
   * Super Admin (jonkomanelesoetsa@gmail.com) is auto-activated.
   * Others are created as CASHIER with 'pending' status.
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
      // Auto-create account for any new user.
      user = await authRepository.createUser({
        firebase_uid: uid,
        email: loginEmail,
        username: name || email.split('@')[0],
        role_name: isSuperAdmin ? 'ADMIN' : 'CASHIER',
        account_status: isSuperAdmin ? 'active' : 'pending',
      });
    } else if (isSuperAdmin) {
      // Ensure the designated Super Admin always has the ADMIN role and active status
      if (user.role_name !== 'ADMIN' && user.role_name !== 'OWNER') {
        await authRepository.updateUserRole(user.id, 'ADMIN');
      }
      if (user.account_status !== 'active') {
        await authRepository.updateUserStatus(user.id, 'active');
      }
      user = await authRepository.findUserById(user.id);
    }

    const status = user.account_status || 'pending';
    if (status === 'suspended') {
      throw new AuthenticationError(
        'Your account has been suspended. Please contact the administrator.',
        'ACCOUNT_SUSPENDED'
      );
    }

    // Check if account is still pending
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

    // GATEKEEPER OTP: Every login attempt triggers a 6-digit code to the Super Admin.
    // This allows the owner to approve every session.
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
      message: 'Authorization code sent to the Super Admin.',
      data: {
        user: normalizeUserResponse(user),
        requiresOtp: true,
        permissions: ROLE_PERMISSIONS_MAP[user.role_name] || [],
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

    res.status(200).json({
      success: true,
      message: 'Identity verified',
    });
  });

  /**
   * Public registration endpoint.
   */
  register = asyncHandler(async (req, res) => {
    const { idToken, displayName } = req.body;
    if (!idToken) throw new ValidationError('idToken is required');

    let decodedToken;
    try {
      decodedToken = await firebaseAdminService.verifyIdToken(idToken);
    } catch (err) {
      throw new AuthenticationError('Invalid authentication token', 'INVALID_TOKEN');
    }

    const { uid, email, name: fbName } = decodedToken;
    const registerEmail = email.toLowerCase();
    const adminEmail = (environment.ownerEmail || 'jonkomanelesoetsa@gmail.com').toLowerCase();
    const isSuperAdmin = registerEmail === adminEmail;

    let user = await authRepository.findUserByEmail(registerEmail);

    if (!user) {
      user = await authRepository.createUser({
        firebase_uid: uid,
        email: registerEmail,
        username: displayName || fbName || registerEmail.split('@')[0],
        role_name: isSuperAdmin ? 'ADMIN' : 'CASHIER',
        account_status: isSuperAdmin ? 'active' : 'pending',
      });
    }

    res.status(201).json({
      success: true,
      message: isSuperAdmin ? 'Admin account ready.' : 'Registration successful. Account pending admin activation.',
      data: { user: normalizeUserResponse(user) }
    });
  });

  /**
   * ADMIN ONLY: List all users registered in the system.
   */
  listUsers = asyncHandler(async (req, res) => {
    if (!isAdminRole(req.user.role)) throw new AuthorizationError('Admin access required');

    const result = await authRepository.listUsers(req.query);
    res.status(200).json({
      success: true,
      data: {
        items: result.items.map(normalizeUserResponse),
        pagination: result.pagination,
      },
    });
  });

  /**
   * ADMIN ONLY: Update account status (Activate/Suspend/Pending).
   */
  updateUserStatus = asyncHandler(async (req, res) => {
    if (!isAdminRole(req.user.role)) throw new AuthorizationError('Admin access required');
    const { id } = req.params;
    const { status } = req.body; // 'active', 'suspended', 'pending'

    const target = await authRepository.findUserById(id);
    if (!target) throw new NotFoundError('User not found');

    const adminEmail = (environment.ownerEmail || 'jonkomanelesoetsa@gmail.com').toLowerCase();
    if (target.email === adminEmail) {
      throw new ValidationError('The Super Admin account status cannot be modified');
    }

    const updated = await authRepository.updateUserStatus(id, status.toLowerCase());
    res.status(200).json({
      success: true,
      message: `User status updated to ${status}`,
      data: normalizeUserResponse(updated)
    });
  });

  /**
   * ADMIN ONLY: Delete user account.
   */
  deleteUser = asyncHandler(async (req, res) => {
    if (!isAdminRole(req.user.role)) throw new AuthorizationError('Admin access required');
    const { id } = req.params;

    const target = await authRepository.findUserById(id);
    if (!target) throw new NotFoundError('User not found');

    const adminEmail = (environment.ownerEmail || 'jonkomanelesoetsa@gmail.com').toLowerCase();
    if (target.email === adminEmail) {
      throw new ValidationError('The Super Admin account cannot be deleted');
    }

    await authRepository.deleteUser(id);
    res.status(200).json({ success: true, message: 'User deleted successfully' });
  });

  /**
   * Account Recovery: Sends Firebase password reset link via custom SMTP.
   */
  requestPasswordReset = asyncHandler(async (req, res) => {
    const { email } = req.body;
    if (!email) throw new ValidationError('Email is required');

    try {
      const link = await firebaseAdminService.generatePasswordResetLink(email.toLowerCase());
      await emailService.sendPasswordResetEmail({
        to: email.toLowerCase(),
        link,
      });
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
