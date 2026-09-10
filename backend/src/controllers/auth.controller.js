'use strict';

const { asyncHandler, generateOtp } = require('../utils/helpers');
const { firebaseAdminService } = require('../services/firebase.service');
const { emailService } = require('../services/email.service');
const authRepository = require('../repositories/auth.repository');
const otpRepository = require('../repositories/otp.repository');
const {
  AuthenticationError,
  ValidationError,
  AuthorizationError,
  NotFoundError,
} = require('../utils/errors');
const environment = require('../config/environment');

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
   * login: Verifies password. If active, triggers code to Super Admin for approval.
   */
  login = asyncHandler(async (req, res) => {
    const { idToken } = req.body;
    const decodedToken = await firebaseAdminService.verifyIdToken(idToken);
    const { uid, email } = decodedToken;

    const loginEmail = email.toLowerCase();
    const adminEmail = (environment.ownerEmail || 'jonkomanelesoetsa@gmail.com').toLowerCase();
    const isSuperAdmin = loginEmail === adminEmail;

    let user = await authRepository.findUserByFirebaseUid(uid);

    if (!user) {
      user = await authRepository.createUser({
        firebase_uid: uid,
        email: loginEmail,
        role_name: isSuperAdmin ? 'ADMIN' : 'CASHIER',
        account_status: isSuperAdmin ? 'active' : 'pending',
      });
    } else if (isSuperAdmin) {
      if (user.role_name !== 'ADMIN' || user.account_status !== 'active') {
        await authRepository.updateUserRole(user.id, 'ADMIN');
        await authRepository.updateUserStatus(user.id, 'active');
        user = await authRepository.findUserById(user.id);
      }
    }

    if (user.account_status === 'suspended') throw new AuthenticationError('Account suspended.');

    if (user.account_status === 'pending' && !isSuperAdmin) {
      return res.status(200).json({
        success: true,
        message: 'Account pending activation.',
        data: { user: normalizeUserResponse(user), isPending: true }
      });
    }

    await authRepository.updateLastLogin(user.id);

    // GATEKEEPER: Always trigger approval code to Admin for login
    const otpCode = generateOtp();
    await otpRepository.createOtp({ email: adminEmail, otpCode, purpose: 'LOGIN_AUTHORIZATION', expiresAt: new Date(Date.now() + 15 * 60 * 1000) });
    await emailService.sendOwnerOtp({ to: adminEmail, otpCode, businessName: 'JonkStore' });

    res.status(200).json({
      success: true,
      message: 'Authorization code sent to Admin.',
      data: { user: normalizeUserResponse(user), requiresOtp: true }
    });
  });

  /**
   * register: Allows anyone to create a pending account.
   */
  register = asyncHandler(async (req, res) => {
    const { idToken, displayName } = req.body;
    const decodedToken = await firebaseAdminService.verifyIdToken(idToken);
    const { uid, email } = decodedToken;

    const loginEmail = email.toLowerCase();
    const adminEmail = (environment.ownerEmail || 'jonkomanelesoetsa@gmail.com').toLowerCase();
    const isSuperAdmin = loginEmail === adminEmail;

    let user = await authRepository.createUser({
      firebase_uid: uid,
      email: loginEmail,
      username: displayName || loginEmail.split('@')[0],
      role_name: isSuperAdmin ? 'ADMIN' : 'CASHIER',
      account_status: isSuperAdmin ? 'active' : 'pending',
    });

    res.status(201).json({
      success: true,
      message: isSuperAdmin ? 'Admin ready' : 'Account created. Pending Admin activation.',
      data: { user: normalizeUserResponse(user) }
    });
  });

  // Admin Management Methods
  listUsers = asyncHandler(async (req, res) => {
    const result = await authRepository.listUsers(req.query);
    res.status(200).json({ success: true, data: { items: result.items.map(normalizeUserResponse), pagination: result.pagination } });
  });

  getUser = asyncHandler(async (req, res) => {
    const user = await authRepository.findUserById(req.params.id);
    if (!user) throw new NotFoundError('User not found');
    res.status(200).json({ success: true, data: normalizeUserResponse(user) });
  });

  updateUserStatus = asyncHandler(async (req, res) => {
    const updated = await authRepository.updateUserStatus(req.params.id, req.body.status);
    res.status(200).json({ success: true, data: normalizeUserResponse(updated) });
  });

  updateUserRole = asyncHandler(async (req, res) => {
    const updated = await authRepository.updateUserRole(req.params.id, req.body.role);
    res.status(200).json({ success: true, data: normalizeUserResponse(updated) });
  });

  deleteUser = asyncHandler(async (req, res) => {
    await authRepository.deleteUser(req.params.id);
    res.status(200).json({ success: true, message: 'Deleted' });
  });

  requestOwnerOtp = asyncHandler(async (req, res) => {
    const adminEmail = (environment.ownerEmail || 'jonkomanelesoetsa@gmail.com').toLowerCase();
    const otpCode = generateOtp();
    await otpRepository.createOtp({ email: adminEmail, otpCode, purpose: 'LOGIN_AUTHORIZATION', expiresAt: new Date(Date.now() + 15 * 60 * 1000) });
    await emailService.sendOwnerOtp({ to: adminEmail, otpCode });
    res.status(200).json({ success: true, message: 'Code sent to Admin.' });
  });

  verifyOwnerOtp = asyncHandler(async (req, res) => {
    const adminEmail = (environment.ownerEmail || 'jonkomanelesoetsa@gmail.com').toLowerCase();
    const otp = await otpRepository.findValidOtp(adminEmail, req.body.otpCode, 'LOGIN_AUTHORIZATION');
    if (!otp) throw new AuthenticationError('Invalid code');
    await otpRepository.markAsUsed(otp.id);
    res.status(200).json({ success: true, message: 'Verified' });
  });

  requestOwnerPasswordReset = asyncHandler(async (req, res) => {
    const link = await firebaseAdminService.generatePasswordResetLink(req.body.email);
    await emailService.sendPasswordResetEmail({ to: req.body.email, link });
    res.status(200).json({ success: true, message: 'Recovery link sent.' });
  });

  me = asyncHandler(async (req, res) => {
    const user = await authRepository.findUserById(req.user.id);
    res.status(200).json({ success: true, data: { user: normalizeUserResponse(user), permissions: ROLE_PERMISSIONS_MAP[user.role_name] || [] } });
  });
}

module.exports = new AuthController();
