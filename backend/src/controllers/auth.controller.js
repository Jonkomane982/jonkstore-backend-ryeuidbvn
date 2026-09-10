'use strict';

const { asyncHandler, generateOtp } = require('../utils/helpers');
const { firebaseAdminService } = require('../services/firebase.service');
const { emailService } = require('../services/email.service');
const authRepository = require('../repositories/auth.repository');
const otpRepository = require('../repositories/otp.repository');
const { AuthenticationError, ValidationError, AuthorizationError, NotFoundError } = require('../utils/errors');
const environment = require('../config/environment');

const ROLE_PERMISSIONS_MAP = {
  ADMIN: ['viewDashboard', 'manageProducts', 'manageCategories', 'manageInventory', 'manageSales', 'manageCustomers', 'manageEmployees', 'manageSettings', 'manageUsers', 'viewProfit', 'useAi'],
  CASHIER: ['viewDashboard', 'manageSales', 'manageCustomers', 'manageNotifications'],
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
    createdAt: user.created_at,
  };
}

class AuthController {
  /**
   * Universal Login: Allows any verified Firebase user.
   * Super Admin is auto-activated; others stay in pending.
   */
  login = asyncHandler(async (req, res) => {
    const { idToken } = req.body;
    const decodedToken = await firebaseAdminService.verifyIdToken(idToken);
    const { uid, email, name } = decodedToken;

    const loginEmail = email.toLowerCase();
    const adminEmail = (environment.ownerEmail || 'jonkomanelesoetsa@gmail.com').toLowerCase();
    const isSuperAdmin = loginEmail === adminEmail;

    let user = await authRepository.findUserByFirebaseUid(uid);

    if (!user) {
      user = await authRepository.createUser({
        firebase_uid: uid,
        email: loginEmail,
        username: name || email.split('@')[0],
        role_name: isSuperAdmin ? 'ADMIN' : 'CASHIER',
        account_status: isSuperAdmin ? 'active' : 'pending',
      });
    }

    const status = user.account_status;
    if (status === 'suspended') throw new AuthenticationError('Account suspended. Contact Admin.');

    if (status === 'pending' && !isSuperAdmin) {
      return res.status(200).json({
        success: true,
        message: 'Account pending activation. Please wait for the Admin to approve your access.',
        data: { user: normalizeUserResponse(user), isPending: true }
      });
    }

    await authRepository.updateLastLogin(user.id);
    res.status(200).json({
      success: true,
      data: { user: normalizeUserResponse(user), permissions: ROLE_PERMISSIONS_MAP[user.role_name] || [] }
    });
  });

  /**
   * ADMIN ONLY: User Management
   */
  listUsers = asyncHandler(async (req, res) => {
    if (req.user.role !== 'ADMIN') throw new AuthorizationError('Admin access required');
    const result = await authRepository.listUsers(req.query);
    res.status(200).json({
      success: true,
      data: { items: result.items.map(normalizeUserResponse) }
    });
  });

  updateUserStatus = asyncHandler(async (req, res) => {
    if (req.user.role !== 'ADMIN') throw new AuthorizationError('Admin access required');
    const { id } = req.params;
    const { status } = req.body;

    const target = await authRepository.findUserById(id);
    if (!target) throw new NotFoundError('User not found');
    if (target.email === (environment.ownerEmail || 'jonkomanelesoetsa@gmail.com').toLowerCase()) {
      throw new ValidationError('Cannot modify status of Super Admin');
    }

    const updated = await authRepository.updateUserStatus(id, status);
    res.status(200).json({
      success: true,
      message: `User status set to ${status}`,
      data: normalizeUserResponse(updated),
    });
  });

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
   * Secure 2FA: Sends code to the user's specific email
   */
  requestOwnerOtp = asyncHandler(async (req, res) => {
    const { email } = req.body;
    const otpCode = generateOtp();
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000);

    await otpRepository.invalidatePreviousOtps(email, 'LOGIN_VERIFICATION');
    await otpRepository.createOtp({ email: email.toLowerCase(), otpCode, purpose: 'LOGIN_VERIFICATION', expiresAt });
    await emailService.sendOwnerOtp({ to: email.toLowerCase(), otpCode, expiresAt });

    res.status(200).json({ success: true, message: 'Verification code sent to your email.' });
  });

  requestOwnerPasswordReset = asyncHandler(async (req, res) => {
    const { email } = req.body;
    const link = await firebaseAdminService.generatePasswordResetLink(email.toLowerCase());
    await emailService.sendPasswordResetEmail({ to: email.toLowerCase(), link });
    res.status(200).json({ success: true, message: 'Recovery link sent.' });
  });
}

module.exports = new AuthController();
