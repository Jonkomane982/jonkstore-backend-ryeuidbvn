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
const { MockFirebaseService, makeNullLogger } = require('./test-helpers');
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
