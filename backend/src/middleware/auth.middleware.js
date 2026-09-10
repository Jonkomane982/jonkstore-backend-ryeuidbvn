'use strict';

const {
  AuthenticationError,
  AuthorizationError,
  ServiceUnavailableError,
} = require('../utils/errors');
const { asyncHandler } = require('../utils/helpers');
const authRepository = require('../repositories/auth.repository');

const ROLE_PERMISSIONS_MAP = {
  ADMIN: [
    'viewDashboard', 'manageProducts', 'manageCategories',
    'manageInventory', 'viewInventory', 'adjustInventory',
    'performStockCount', 'transferStock', 'viewInventoryCost',
    'manageSales', 'manageCustomers', 'manageSuppliers', 'managePurchases',
    'manageReports', 'manageNotifications', 'manageEmployees', 'manageSettings',
    'viewProfit', 'useAi', 'manageUsers',
  ],
  OWNER: [
    'viewDashboard', 'manageProducts', 'manageCategories',
    'manageInventory', 'viewInventory', 'adjustInventory',
    'performStockCount', 'transferStock', 'viewInventoryCost',
    'manageSales', 'manageCustomers', 'manageSuppliers', 'managePurchases',
    'manageReports', 'manageNotifications', 'manageEmployees', 'manageSettings',
    'viewProfit', 'useAi', 'manageUsers',
  ],
  MANAGER: [
    'viewDashboard', 'manageProducts', 'manageCategories', 'manageInventory',
    'manageCustomers', 'manageSuppliers', 'managePurchases', 'manageReports',
    'manageNotifications', 'useAi',
  ],
  CASHIER: [
    'viewDashboard', 'manageSales', 'manageCustomers', 'manageNotifications',
  ],
  STORE_ASSISTANT: [
    'viewDashboard', 'manageInventory', 'manageNotifications',
  ],
};

async function enrichUserFromDb(req) {
  if (!req.user || !req.user.uid) return;
  try {
    const dbUser = await authRepository.findUserByFirebaseUid(req.user.uid);
    if (dbUser) {
      const role = dbUser.role_name || (req.user.claims && req.user.claims.role) || null;
      req.user.id = dbUser.id;
      req.user.email = dbUser.email || req.user.email;
      req.user.username = dbUser.username;
      req.user.role = role;
      req.user.roles = role ? [role] : (req.user.roles || []);
      req.user.accountStatus = dbUser.account_status || 'active';
      req.user.isActive = dbUser.is_active;
      req.user.permissions = ROLE_PERMISSIONS_MAP[role] || (req.user.permissions || []);
      if (!req.user.claims) req.user.claims = {};
      if (role) req.user.claims.role = role;
      req.user.claims.permissions = req.user.permissions;
    }
  } catch (err) {
    // DB enrichment failures should not block the request entirely;
    // fall back to Firebase claims only.
  }
}

function requireAuthentication(firebaseService) {
  return asyncHandler(async function requireAuthMiddleware(req, _res, next) {
    const header = req.headers.authorization || '';
    const [scheme, token] = header.split(' ');
    if (scheme !== 'Bearer' || !token) {
      return next(new AuthenticationError('Missing or invalid authorization header'));
    }
    if (!firebaseService || !firebaseService.verifyIdToken) {
      return next(new ServiceUnavailableError(
        'Authentication service is not available',
        'AUTH_SERVICE_UNAVAILABLE'
      ));
    }
    try {
      const decodedToken = await firebaseService.verifyIdToken(token, true);
      if (!decodedToken || !decodedToken.uid) {
        return next(new AuthenticationError('Invalid authentication token'));
      }
      req.user = {
        ...(req.user || {}),
        uid: decodedToken.uid,
        email: decodedToken.email || null,
        emailVerified: decodedToken.email_verified || false,
        firebaseSignInProvider: decodedToken.firebase && decodedToken.firebase.sign_in_provider
          ? decodedToken.firebase.sign_in_provider
          : null,
        claims: decodedToken.claims || {},
        token: decodedToken,
      };
      await enrichUserFromDb(req);
      return next();
    } catch (err) {
      if (err && err instanceof ServiceUnavailableError) {
        return next(err);
      }
      const code = err && err.code ? err.code : 'unknown';
      if (code === 'TOKEN_EXPIRED' || code === 'auth/id-token-expired') {
        return next(new AuthenticationError('Token expired', 'TOKEN_EXPIRED'));
      }
      if (code === 'TOKEN_REVOKED' || code === 'auth/id-token-revoked') {
        return next(new AuthenticationError('Token revoked', 'TOKEN_REVOKED'));
      }
      if (code === 'INVALID_TOKEN' || code === 'auth/argument-error' || code === 'auth/invalid-id-token') {
        return next(new AuthenticationError('Invalid token format', 'INVALID_TOKEN'));
      }
      if (code === 'AUTH_FAILED') {
        return next(new AuthenticationError('Authentication failed', 'AUTH_FAILED'));
      }
      return next(new AuthenticationError('Authentication failed', 'AUTH_FAILED'));
    }
  });
}

function requireRole(...allowedRoles) {
  const allowed = new Set(allowedRoles.filter(Boolean).map(r => String(r).toUpperCase()));
  return function requireRoleMiddleware(req, _res, next) {
    if (!req.user) {
      return next(new AuthenticationError());
    }
    if (allowed.size === 0) return next();
    const userRoles = Array.isArray(req.user.roles)
      ? req.user.roles.map(r => String(r).toUpperCase())
      : [];
    const claimsRole = (req.user.claims && req.user.claims.role)
      ? String(req.user.claims.role).toUpperCase()
      : null;
    const directRole = req.user.role ? String(req.user.role).toUpperCase() : null;
    if (directRole && allowed.has(directRole)) return next();
    if (claimsRole && allowed.has(claimsRole)) return next();
    for (const r of userRoles) {
      if (allowed.has(r)) return next();
    }
    return next(new AuthorizationError());
  };
}

function requirePermission(...permissions) {
  const required = new Set(permissions.filter(Boolean));
  return function requirePermissionMiddleware(req, _res, next) {
    if (!req.user) {
      return next(new AuthenticationError());
    }
    if (required.size === 0) return next();
    const userPerms = Array.isArray(req.user.permissions) ? new Set(req.user.permissions) : new Set();
    const claimsPerms = (req.user.claims && Array.isArray(req.user.claims.permissions))
      ? req.user.claims.permissions
      : [];
    for (const p of claimsPerms) userPerms.add(p);
    for (const perm of required) {
      if (userPerms.has(perm)) return next();
    }
    return next(new AuthorizationError('Insufficient permissions'));
  };
}

function optionalAuthentication(firebaseService) {
  return asyncHandler(async function optionalAuthMiddleware(req, _res, next) {
    const header = req.headers.authorization || '';
    const [scheme, token] = header.split(' ');
    if (scheme !== 'Bearer' || !token) {
      return next();
    }
    if (!firebaseService || !firebaseService.verifyIdToken) {
      return next();
    }
    try {
      const decodedToken = await firebaseService.verifyIdToken(token, false);
      if (decodedToken && decodedToken.uid) {
        req.user = {
          uid: decodedToken.uid,
          email: decodedToken.email || null,
          emailVerified: decodedToken.email_verified || false,
          claims: decodedToken.claims || {},
          token: decodedToken,
        };
        await enrichUserFromDb(req);
      }
    } catch {
      // Optional auth: silently ignore invalid tokens or unavailable service
    }
    return next();
  });
}

module.exports = {
  requireAuthentication,
  requireRole,
  requirePermission,
  optionalAuthentication,
};
