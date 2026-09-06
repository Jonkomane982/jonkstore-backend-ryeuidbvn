'use strict';

const express = require('express');
const request = require('supertest');
const {
  errorHandlerMiddleware,
  notFoundMiddleware,
} = require('../src/middleware/error.middleware');
const {
  AppError,
  NotFoundError,
  ValidationError,
  AuthenticationError,
  AuthorizationError,
  DatabaseError,
} = require('../src/utils/errors');

function buildAppWithRoute(handler) {
  const app = express();
  app.use(express.json());
  app.get('/ok', (_req, res) => res.json({ ok: true }));
  app.get('/throw-app', (_req, _res) => {
    throw new AppError('boom', 503, 'SERVICE_DOWN');
  });
  app.get('/throw-notfound', (_req, _res) => {
    throw new NotFoundError('item gone', 'ITEM_MISSING');
  });
  app.get('/throw-validation', (_req, _res) => {
    throw new ValidationError('bad input', [
      { field: 'x', message: 'x required' },
      { field: 'y', message: 'y required' },
    ], 'BAD_FORM');
  });
  app.get('/throw-auth', (_req, _res) => {
    throw new AuthenticationError('no token', 'NO_TOKEN');
  });
  app.get('/throw-forbidden', (_req, _res) => {
    throw new AuthorizationError('cannot touch', 'ROLE_MISSING');
  });
  app.get('/throw-db', (_req, _res) => {
    throw new DatabaseError('db is down', new Error('pg error'), 'PG_DOWN');
  });
  app.get('/throw-raw', (_req, _res) => {
    throw new Error('raw unexpected');
  });
  if (typeof handler === 'function') {
    app.get('/custom', handler);
  }
  app.use(notFoundMiddleware);
  app.use(errorHandlerMiddleware);
  return app;
}

describe('Error Classes', () => {
  it('AppError sets code, statusCode, isOperational', () => {
    const e = new AppError('oops', 502, 'GATEWAY');
    expect(e.message).toBe('oops');
    expect(e.statusCode).toBe(502);
    expect(e.code).toBe('GATEWAY');
    expect(e.isOperational).toBe(true);
    expect(e.toJSON().error.message).toBe('oops');
  });

  it('subclasses have correct HTTP codes', () => {
    expect(new NotFoundError().statusCode).toBe(404);
    expect(new ValidationError().statusCode).toBe(400);
    expect(new AuthenticationError().statusCode).toBe(401);
    expect(new AuthorizationError().statusCode).toBe(403);
    expect(new DatabaseError().statusCode).toBe(500);
  });

  it('ValidationError exposes errors array via toJSON', () => {
    const e = new ValidationError('fail', [{ field: 'a', message: 'bad a' }]);
    const body = e.toJSON();
    expect(body.error.errors.length).toBe(1);
    expect(body.error.errors[0].field).toBe('a');
  });
});

describe('Error Handling Middleware', () => {
  let app;
  beforeAll(() => {
    app = buildAppWithRoute();
  });

  it('passes normal responses untouched', async () => {
    const res = await request(app).get('/ok');
    expect(res.status).toBe(200);
    expect(res.body.ok).toBe(true);
  });

  it('renders AppError with status and JSON shape', async () => {
    const res = await request(app).get('/throw-app');
    expect(res.status).toBe(503);
    expect(res.body.error.code).toBe('SERVICE_DOWN');
    expect(res.body.error.message).toBe('boom');
    expect(res.body.error.requestId).toBeDefined();
    expect(res.body.error.timestamp).toMatch(/^\d{4}-\d{2}-\d{2}T/);
  });

  it('renders NotFoundError as 404 with custom code', async () => {
    const res = await request(app).get('/throw-notfound');
    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('ITEM_MISSING');
  });

  it('renders ValidationError as 400 with field errors', async () => {
    const res = await request(app).get('/throw-validation');
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('BAD_FORM');
    expect(res.body.error.errors.length).toBe(2);
  });

  it('renders AuthenticationError as 401', async () => {
    const res = await request(app).get('/throw-auth');
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('NO_TOKEN');
  });

  it('renders AuthorizationError as 403', async () => {
    const res = await request(app).get('/throw-forbidden');
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('ROLE_MISSING');
  });

  it('renders DatabaseError as 500', async () => {
    const res = await request(app).get('/throw-db');
    expect(res.status).toBe(500);
    expect(res.body.error.code).toBe('PG_DOWN');
  });

  it('catches raw unexpected Error and sanitizes to INTERNAL_ERROR', async () => {
    const res = await request(app).get('/throw-raw');
    expect(res.status).toBe(500);
    expect(res.body.error.code).toBe('INTERNAL_ERROR');
  });

  it('notFoundMiddleware catches unknown routes with 404', async () => {
    const res = await request(app).get('/definitely-not-here');
    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('ROUTE_NOT_FOUND');
  });

  it('invalid JSON body returns INVALID_JSON 400', async () => {
    const res = await request(app)
      .post('/ok')
      .set('content-type', 'application/json')
      .send('{ this is broken json }');
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('INVALID_JSON');
  });

  it('request id is attached to every error body', async () => {
    const res = await request(app).get('/throw-app');
    expect(typeof res.body.error.requestId).toBe('string');
    expect(res.body.error.requestId.length).toBeGreaterThan(0);
  });
});
