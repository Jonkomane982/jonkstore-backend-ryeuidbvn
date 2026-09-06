'use strict';

const {
  AuthenticationError,
  AuthorizationError,
  ServiceUnavailableError,
} = require('../utils/errors');
const { asyncHandler } = require('../utils/helpers');

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
  const allowed = new Set(allowedRoles.filter(Boolean));
  return function requireRoleMiddleware(req, _res, next) {
    if (!req.user) {
      return next(new AuthenticationError());
    }
    if (allowed.size === 0) return next();
    const userRoles = Array.isArray(req.user.roles) ? req.user.roles : [];
    const claimsRole = (req.user.claims && req.user.claims.role) || null;
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
