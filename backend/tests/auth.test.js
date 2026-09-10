'use strict';

const express = require('express');
const request = require('supertest');
const {
  requireAuthentication,
  requireRole,
  requirePermission,
  optionalAuthentication,
} = require('../src/middleware/auth.middleware');
const { errorHandlerMiddleware } = require('../src/middleware/error.middleware');
const { MockFirebaseService, MockEmailService, makeNullLogger, buildTestApp } = require('./test-helpers');
const { ServiceUnavailableError, AppError } = require('../src/utils/errors');
const { z } = require('zod');

function buildAuthApp(firebase, options = {}) {
  const app = express();
  app.use(express.json());

  app.get('/public', (_req, res) => res.json({ route: 'public' }));

  if (options.optional !== false) {
    app.get('/optional', optionalAuthentication(firebase), (req, res) => {
      res.json({ user: req.user ? { uid: req.user.uid } : null });
    });
  }

  app.get('/protected', requireAuthentication(firebase), (req, res) => {
    res.json({ uid: req.user.uid, email: req.user.email });
  });

  app.get(
    '/admin',
    requireAuthentication(firebase),
    requireRole('admin', 'owner'),
    (_req, res) => res.json({ role: 'ok' })
  );

  app.get(
    '/suppliers-manage',
    requireAuthentication(firebase),
    requirePermission('manageSuppliers'),
    (_req, res) => res.json({ perm: 'ok' })
  );

  app.use(errorHandlerMiddleware);
  return app;
}

describe('Authentication Middleware Structure', () => {
  it('requireAuthentication returns middleware function', () => {
    const firebase = new MockFirebaseService();
    const mw = requireAuthentication(firebase);
    expect(typeof mw).toBe('function');
    expect(mw.length).toBe(3);
  });

  it('requireRole returns middleware function that accepts 3 args', () => {
    const mw = requireRole('admin');
    expect(typeof mw).toBe('function');
    expect(mw.length).toBe(3);
  });

  it('requirePermission returns middleware function', () => {
    const mw = requirePermission('doThing');
    expect(typeof mw).toBe('function');
  });

  it('optionalAuthentication returns middleware function', () => {
    const firebase = new MockFirebaseService();
    const mw = optionalAuthentication(firebase);
    expect(typeof mw).toBe('function');
  });
});

describe('Authentication Middleware Behavior', () => {
  it('rejects requests with no Authorization header', async () => {
    const firebase = new MockFirebaseService();
    const app = buildAuthApp(firebase);
    const res = await request(app).get('/protected');
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('AUTHENTICATION_REQUIRED');
  });

  it('rejects requests with non-Bearer scheme', async () => {
    const firebase = new MockFirebaseService();
    const app = buildAuthApp(firebase);
    const res = await request(app)
      .get('/protected')
      .set('Authorization', 'Basic abc123');
    expect(res.status).toBe(401);
  });

  it('rejects invalid tokens with appropriate 401', async () => {
    const firebase = new MockFirebaseService({
      tokenError: { code: 'auth/invalid-id-token' },
    });
    const app = buildAuthApp(firebase);
    const res = await request(app)
      .get('/protected')
      .set('Authorization', 'Bearer not-a-real-token');
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('INVALID_TOKEN');
  });

  it('rejects expired tokens with TOKEN_EXPIRED', async () => {
    const firebase = new MockFirebaseService({
      tokenError: { code: 'auth/id-token-expired' },
    });
    const app = buildAuthApp(firebase);
    const res = await request(app)
      .get('/protected')
      .set('Authorization', 'Bearer expired');
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('TOKEN_EXPIRED');
  });

  it('accepts valid tokens and attaches req.user', async () => {
    const firebase = new MockFirebaseService({
      configured: true,
      tokenResult: {
        uid: 'user-123',
        email: 'owner@test.local',
        email_verified: true,
        firebase: { sign_in_provider: 'password' },
        claims: { role: 'owner', permissions: ['manageSuppliers', 'manageProducts'] },
      },
    });
    const app = buildAuthApp(firebase);
    const res = await request(app)
      .get('/protected')
      .set('Authorization', 'Bearer real-token');
    expect(res.status).toBe(200);
    expect(res.body.uid).toBe('user-123');
    expect(res.body.email).toBe('owner@test.local');
  });

  it('optionalAuthentication leaves req.user=null when no token', async () => {
    const firebase = new MockFirebaseService();
    const app = buildAuthApp(firebase);
    const res = await request(app).get('/optional');
    expect(res.status).toBe(200);
    expect(res.body.user).toBeNull();
  });

  it('optionalAuthentication attaches user when valid token', async () => {
    const firebase = new MockFirebaseService({
      configured: true,
      tokenResult: {
        uid: 'opt-user-1',
        email_verified: false,
      },
    });
    const app = buildAuthApp(firebase);
    const res = await request(app)
      .get('/optional')
      .set('Authorization', 'Bearer opt-token');
    expect(res.status).toBe(200);
    expect(res.body.user.uid).toBe('opt-user-1');
  });

  it('requireRole blocks non-matching roles with 403', async () => {
    const firebase = new MockFirebaseService({
      configured: true,
      tokenResult: {
        uid: 'u',
        email_verified: true,
        claims: { role: 'assistant' },
      },
    });
    const app = buildAuthApp(firebase);
    const res = await request(app)
      .get('/admin')
      .set('Authorization', 'Bearer t');
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('FORBIDDEN');
  });

  it('requireRole allows matching role (owner)', async () => {
    const firebase = new MockFirebaseService({
      configured: true,
      tokenResult: { uid: 'u', email_verified: true, claims: { role: 'owner' } },
    });
    const app = buildAuthApp(firebase);
    const res = await request(app)
      .get('/admin')
      .set('Authorization', 'Bearer t');
    expect(res.status).toBe(200);
    expect(res.body.role).toBe('ok');
  });

  it('requirePermission blocks missing permission', async () => {
    const firebase = new MockFirebaseService({
      configured: true,
      tokenResult: {
        uid: 'u',
        email_verified: true,
        claims: { role: 'assistant', permissions: ['viewReports'] },
      },
    });
    const app = buildAuthApp(firebase);
    const res = await request(app)
      .get('/suppliers-manage')
      .set('Authorization', 'Bearer t');
    expect(res.status).toBe(403);
  });

  it('requirePermission allows when permission present in claims', async () => {
    const firebase = new MockFirebaseService({
      configured: true,
      tokenResult: {
        uid: 'u',
        email_verified: true,
        claims: { role: 'owner', permissions: ['manageSuppliers'] },
      },
    });
    const app = buildAuthApp(firebase);
    const res = await request(app)
      .get('/suppliers-manage')
      .set('Authorization', 'Bearer t');
    expect(res.status).toBe(200);
    expect(res.body.perm).toBe('ok');
  });
});

describe('Owner Forgot Password Endpoint (/api/auth/owner/forgot-password)', () => {
  const OWNER_EMAIL = 'owner@test.local';

  afterEach(() => {
    jest.resetModules();
  });

  it('returns 200 generic message AND dispatches email when owner email matches', async () => {
    const { app, services } = buildTestApp();
    const res = await request(app)
      .post('/api/auth/owner/forgot-password')
      .send({ email: OWNER_EMAIL });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.message).toMatch(/authorized/);
    expect(res.body.message).toMatch(/password reset link/);

    const linkCalls = services.firebase.calls.filter(
      (c) => c.method === 'generatePasswordResetLink'
    );
    expect(linkCalls).toHaveLength(1);
    expect(linkCalls[0].email).toBe(OWNER_EMAIL);

    const resetEmails = services.email.sent.filter((e) => e._tag === 'password-reset');
    expect(resetEmails).toHaveLength(1);
    expect(resetEmails[0].to).toBe(OWNER_EMAIL);
    expect(resetEmails[0].link).toContain('mock-oob-code');
  });

  it('returns 200 generic message but does NOT dispatch email when email is not the owner (masking)', async () => {
    const { app, services } = buildTestApp();
    const res = await request(app)
      .post('/api/auth/owner/forgot-password')
      .send({ email: 'attacker@evil.local' });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.message).toMatch(/authorized/);

    const linkCalls = services.firebase.calls.filter(
      (c) => c.method === 'generatePasswordResetLink'
    );
    expect(linkCalls).toHaveLength(0);

    const resetEmails = services.email.sent.filter((e) => e._tag === 'password-reset');
    expect(resetEmails).toHaveLength(0);
  });

  it('rejects invalid body (missing email) with 400 ValidationError', async () => {
    const { app } = buildTestApp();
    const res = await request(app)
      .post('/api/auth/owner/forgot-password')
      .send({});

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
    expect(res.body.error.message).toMatch(/Invalid request body/);
  });

  it('returns 503 ServiceUnavailable when Firebase Admin cannot generate link (infrastructure error, not masked)', async () => {
    const firebase = new MockFirebaseService({
      passwordResetLinkError: new ServiceUnavailableError(
        'Firebase Auth service unavailable',
        'FIREBASE_UNAVAILABLE'
      ),
    });
    const { app, services } = buildTestApp({ firebase });
    const res = await request(app)
      .post('/api/auth/owner/forgot-password')
      .send({ email: OWNER_EMAIL });

    expect(res.status).toBe(503);
    expect(res.body.error.code).toBe('FIREBASE_UNAVAILABLE');

    const resetEmails = services.email.sent.filter((e) => e._tag === 'password-reset');
    expect(resetEmails).toHaveLength(0);
  });

  it('returns 5xx when SMTP send fails after Firebase link generated (infrastructure error, not masked)', async () => {
    const email = new MockEmailService({
      passwordResetError: new AppError('Failed to send email', 502, 'EMAIL_SEND_FAILED'),
    });
    const { app, services } = buildTestApp({ email });
    const res = await request(app)
      .post('/api/auth/owner/forgot-password')
      .send({ email: OWNER_EMAIL });

    expect(res.status).toBe(502);
    expect(res.body.error.code).toBe('EMAIL_SEND_FAILED');

    const linkCalls = services.firebase.calls.filter(
      (c) => c.method === 'generatePasswordResetLink'
    );
    expect(linkCalls).toHaveLength(1);
    expect(linkCalls[0].email).toBe(OWNER_EMAIL);
  });
});

describe('Open Registration & Public Login (Any Email Allowed)', () => {
  const OWNER_EMAIL = 'owner@test.local';
  const USER_EMAIL = 'user@example.com';

  function setupMocks(mockOverrides = {}) {
    jest.resetModules();
    const tokenUser = mockOverrides.tokenUser || {
      uid: 'firebase-uid-1',
      email: USER_EMAIL,
      name: 'Jane Doe',
      email_verified: true,
      claims: {},
    };
    const userRow = mockOverrides.userRow || null;
    const createdUserRow = mockOverrides.createdUserRow || {
      id: 'db-user-1',
      firebase_uid: 'firebase-uid-1',
      email: USER_EMAIL,
      username: 'janedoe',
      role_name: 'CASHIER',
      is_active: false,
      account_status: 'pending',
      last_login_at: null,
      created_at: new Date().toISOString(),
    };

    jest.doMock('../src/repositories/auth.repository', () => ({
      findUserByFirebaseUid: jest.fn(async (_uid) => userRow),
      findUserByEmail: jest.fn(async (_email) => userRow),
      findUserById: jest.fn(async (id) => ({ ...createdUserRow, id })),
      createUser: jest.fn(async (data) => ({
        ...createdUserRow,
        email: data.email,
        firebase_uid: data.firebase_uid,
        username: data.username || createdUserRow.username,
        role_name: data.role_name || createdUserRow.role_name,
        account_status: data.account_status || createdUserRow.account_status,
        is_active: (data.account_status || createdUserRow.account_status) === 'active',
      })),
      updateLastLogin: jest.fn(async (_id) => null),
      updateUserStatus: jest.fn(async (id, status) => ({
        id, email: USER_EMAIL, role_name: 'CASHIER', account_status: status, is_active: status === 'active',
      })),
      updateUserRole: jest.fn(async (id, role) => ({
        id, email: USER_EMAIL, role_name: role, account_status: 'active',
      })),
      deleteUser: jest.fn(async (id) => ({ id, email: USER_EMAIL })),
      listUsers: jest.fn(async () => ({
        items: [createdUserRow],
        pagination: { page: 1, limit: 50, total: 1, totalPages: 1 },
      })),
      ensureAccountStatusColumn: jest.fn(async () => null),
    }));

    const firebase = new MockFirebaseService({
      configured: true,
      tokenResult: tokenUser,
    });

    const email = new MockEmailService();

    const { buildTestApp: build } = require('./test-helpers');
    const result = build({ firebase, email });
    return { ...result, firebase };
  }

  afterEach(() => {
    jest.resetModules();
    jest.restoreAllMocks();
  });

  it('POST /auth/login allows any verified email (not just owner) and creates pending CASHIER', async () => {
    const { app, firebase } = setupMocks({
      tokenUser: {
        uid: 'firebase-new',
        email: USER_EMAIL,
        name: 'Jane',
        email_verified: true,
        claims: {},
      },
      userRow: null,
    });

    const res = await request(app)
      .post('/api/auth/login')
      .send({ idToken: 'any-token-works' });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.user.email).toBe(USER_EMAIL);
    expect(res.body.data.user.role).toBe('CASHIER');
    expect(res.body.data.user.accountStatus).toBe('pending');
    expect(res.body.data.permissions).toEqual(expect.arrayContaining(['viewDashboard', 'manageSales']));
    expect(res.body.message).toMatch(/pending/);

    const authRepo = require('../src/repositories/auth.repository');
    expect(authRepo.createUser).toHaveBeenCalledTimes(1);
    expect(authRepo.createUser.mock.calls[0][0].role_name).toBe('CASHIER');
    expect(authRepo.createUser.mock.calls[0][0].account_status).toBe('pending');
    expect(firebase.calls.some((c) => c.token)).toBe(true);
  });

  it('POST /auth/login auto-assigns ADMIN role and active status to OWNER_EMAIL', async () => {
    const { app } = setupMocks({
      tokenUser: {
        uid: 'firebase-admin',
        email: OWNER_EMAIL,
        name: 'Owner',
        email_verified: true,
        claims: {},
      },
      userRow: null,
      createdUserRow: {
        id: 'db-admin',
        firebase_uid: 'firebase-admin',
        email: OWNER_EMAIL,
        username: 'owner',
        role_name: 'ADMIN',
        is_active: true,
        account_status: 'active',
        last_login_at: null,
        created_at: new Date().toISOString(),
      },
    });

    const res = await request(app)
      .post('/api/auth/login')
      .send({ idToken: 'owner-token' });

    expect(res.status).toBe(200);
    expect(res.body.data.user.email).toBe(OWNER_EMAIL);
    expect(res.body.data.user.role).toBe('ADMIN');
    expect(res.body.data.user.accountStatus).toBe('active');
    expect(res.body.data.permissions).toContain('manageUsers');

    const authRepo = require('../src/repositories/auth.repository');
    const createArg = authRepo.createUser.mock.calls[0][0];
    expect(createArg.role_name).toBe('ADMIN');
    expect(createArg.account_status).toBe('active');
  });

  it('POST /auth/login rejects when missing idToken (400 validation)', async () => {
    const { app } = setupMocks();
    const res = await request(app).post('/api/auth/login').send({});
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('POST /auth/register creates new user for any email and returns pending status', async () => {
    const { app } = setupMocks({
      tokenUser: {
        uid: 'firebase-new-user',
        email: 'newbie@test.local',
        email_verified: true,
        claims: {},
      },
      userRow: null,
      createdUserRow: {
        id: 'db-newbie',
        firebase_uid: 'firebase-new-user',
        email: 'newbie@test.local',
        username: 'newbie',
        role_name: 'CASHIER',
        is_active: false,
        account_status: 'pending',
        created_at: new Date().toISOString(),
      },
    });

    const res = await request(app)
      .post('/api/auth/register')
      .send({ idToken: 'register-token', displayName: 'New User' });

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.data.user.accountStatus).toBe('pending');
    expect(res.body.message).toMatch(/admin will review/);

    const authRepo = require('../src/repositories/auth.repository');
    expect(authRepo.createUser).toHaveBeenCalledTimes(1);
  });

  it('POST /auth/register for OWNER_EMAIL grants ADMIN + active', async () => {
    const { app } = setupMocks({
      tokenUser: {
        uid: 'firebase-owner-2',
        email: OWNER_EMAIL,
        email_verified: true,
        claims: {},
      },
      userRow: null,
      createdUserRow: {
        id: 'db-owner-2',
        firebase_uid: 'firebase-owner-2',
        email: OWNER_EMAIL,
        username: 'owner',
        role_name: 'ADMIN',
        is_active: true,
        account_status: 'active',
        created_at: new Date().toISOString(),
      },
    });

    const res = await request(app)
      .post('/api/auth/register')
      .send({ idToken: 'register-owner-token' });

    expect(res.status).toBe(201);
    expect(res.body.data.user.role).toBe('ADMIN');
    expect(res.body.data.user.accountStatus).toBe('active');
  });

  it('POST /auth/register idempotent: 200 if user already exists', async () => {
    const { app } = setupMocks({
      tokenUser: {
        uid: 'firebase-exists',
        email: 'existing@test.local',
        email_verified: true,
        claims: {},
      },
      userRow: {
        id: 'db-existing',
        firebase_uid: 'firebase-exists',
        email: 'existing@test.local',
        username: 'existing',
        role_name: 'CASHIER',
        is_active: true,
        account_status: 'active',
        created_at: new Date().toISOString(),
      },
    });

    const res = await request(app)
      .post('/api/auth/register')
      .send({ idToken: 'any' });

    expect(res.status).toBe(200);
    expect(res.body.message).toMatch(/already exists/);
  });
});

describe('Admin User Management Endpoints (RBAC Protected)', () => {
  const OWNER_EMAIL = 'owner@test.local';
  const TARGET_ID = 'db-user-1';

  function setupAdminApp(actorRole = 'ADMIN') {
    jest.resetModules();

    jest.doMock('../src/repositories/auth.repository', () => ({
      findUserByFirebaseUid: jest.fn(async (uid) => ({
        id: uid === 'admin-uid' ? 'db-admin-1' : TARGET_ID,
        firebase_uid: uid,
        email: uid === 'admin-uid' ? OWNER_EMAIL : 'user@test.local',
        username: uid === 'admin-uid' ? 'admin' : 'user',
        role_name: actorRole,
        account_status: 'active',
        is_active: true,
        last_login_at: null,
        created_at: new Date().toISOString(),
      })),
      findUserById: jest.fn(async (id) => ({
        id,
        email: id === 'db-admin-1' ? OWNER_EMAIL : 'user@test.local',
        username: id === 'db-admin-1' ? 'admin' : 'user',
        role_name: id === 'db-admin-1' ? actorRole : 'CASHIER',
        account_status: 'active',
        is_active: true,
        created_at: new Date().toISOString(),
      })),
      findUserByEmail: jest.fn(async (email) => ({
        id: email === OWNER_EMAIL ? 'db-admin-1' : TARGET_ID,
        email,
        username: email.split('@')[0],
        role_name: email === OWNER_EMAIL ? actorRole : 'CASHIER',
        account_status: 'active',
        is_active: true,
      })),
      listUsers: jest.fn(async () => ({
        items: [
          { id: TARGET_ID, email: 'user@test.local', username: 'user', role_name: 'CASHIER', account_status: 'pending', is_active: false, created_at: new Date().toISOString() },
        ],
        pagination: { page: 1, limit: 50, total: 1, totalPages: 1 },
      })),
      updateUserStatus: jest.fn(async (id, status) => ({
        id, email: 'user@test.local', role_name: 'CASHIER', account_status: status, is_active: status === 'active',
      })),
      updateUserRole: jest.fn(async (id, role) => ({
        id, email: 'user@test.local', role_name: role, account_status: 'active',
      })),
      deleteUser: jest.fn(async (id) => ({ id, email: 'user@test.local' })),
      ensureAccountStatusColumn: jest.fn(async () => null),
      createUser: jest.fn(async (d) => ({ id: 'x', ...d, created_at: new Date().toISOString() })),
      updateLastLogin: jest.fn(async () => null),
      setupNewBusiness: jest.fn(async () => ({ id: 'biz-1' })),
    }));

    const firebase = new MockFirebaseService({
      configured: true,
      tokenResult: {
        uid: 'admin-uid',
        email: OWNER_EMAIL,
        email_verified: true,
        claims: { role: actorRole.toLowerCase(), permissions: ['manageUsers'] },
      },
    });

    const email = new MockEmailService();
    const { buildTestApp: build } = require('./test-helpers');
    return build({ firebase, email });
  }

  afterEach(() => {
    jest.resetModules();
    jest.restoreAllMocks();
  });

  it('GET /auth/users returns paginated users list for ADMIN role', async () => {
    const { app } = setupAdminApp('ADMIN');
    const res = await request(app)
      .get('/api/auth/users')
      .set('Authorization', 'Bearer admin-token');

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(Array.isArray(res.body.data.items)).toBe(true);
    expect(res.body.data.items[0].email).toBe('user@test.local');
    expect(res.body.data.pagination.total).toBe(1);
  });

  it('GET /auth/users rejects CASHIER role with 403', async () => {
    const { app } = setupAdminApp('CASHIER');
    const res = await request(app)
      .get('/api/auth/users')
      .set('Authorization', 'Bearer cashier-token');

    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('FORBIDDEN');
  });

  it('GET /auth/users rejects unauthenticated with 401', async () => {
    const { app } = setupAdminApp('ADMIN');
    const res = await request(app).get('/api/auth/users');
    expect(res.status).toBe(401);
  });

  it('PATCH /auth/users/:id/status activates pending account', async () => {
    const { app } = setupAdminApp('ADMIN');
    const res = await request(app)
      .patch(`/api/auth/users/${TARGET_ID}/status`)
      .set('Authorization', 'Bearer admin-token')
      .send({ status: 'active' });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.user.accountStatus).toBe('active');
    expect(res.body.message).toMatch(/updated to active/);
  });

  it('PATCH /auth/users/:id/status suspends active account', async () => {
    const { app } = setupAdminApp('ADMIN');
    const res = await request(app)
      .patch(`/api/auth/users/${TARGET_ID}/status`)
      .set('Authorization', 'Bearer admin-token')
      .send({ status: 'suspended' });

    expect(res.status).toBe(200);
    expect(res.body.data.user.accountStatus).toBe('suspended');
  });

  it('PATCH /auth/users/:id/status rejects invalid status (400)', async () => {
    const { app } = setupAdminApp('ADMIN');
    const res = await request(app)
      .patch(`/api/auth/users/${TARGET_ID}/status`)
      .set('Authorization', 'Bearer admin-token')
      .send({ status: 'banned' });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('PATCH /auth/users/:id/role upgrades user to MANAGER', async () => {
    const { app } = setupAdminApp('ADMIN');
    const res = await request(app)
      .patch(`/api/auth/users/${TARGET_ID}/role`)
      .set('Authorization', 'Bearer admin-token')
      .send({ role: 'MANAGER' });

    expect(res.status).toBe(200);
    expect(res.body.data.user.role).toBe('MANAGER');
  });

  it('PATCH /auth/users/:id/role rejects invalid role (400)', async () => {
    const { app } = setupAdminApp('ADMIN');
    const res = await request(app)
      .patch(`/api/auth/users/${TARGET_ID}/role`)
      .set('Authorization', 'Bearer admin-token')
      .send({ role: 'SUPERHERO' });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('DELETE /auth/users/:id removes user account', async () => {
    const { app } = setupAdminApp('ADMIN');
    const res = await request(app)
      .delete(`/api/auth/users/${TARGET_ID}`)
      .set('Authorization', 'Bearer admin-token');

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.email).toBe('user@test.local');
    expect(res.body.message).toMatch(/deleted/);
  });

  it('GET /auth/me includes DB-enriched user + permissions', async () => {
    const { app } = setupAdminApp('ADMIN');
    const res = await request(app)
      .get('/api/auth/me')
      .set('Authorization', 'Bearer admin-token');

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.user.email).toBe(OWNER_EMAIL);
    expect(res.body.data.permissions).toContain('manageUsers');
  });
});
