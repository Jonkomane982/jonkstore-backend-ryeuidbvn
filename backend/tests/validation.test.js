'use strict';

const express = require('express');
const request = require('supertest');
const { z } = require('zod');
const { validate } = require('../src/middleware/validation.middleware');
const { errorHandlerMiddleware, notFoundMiddleware } = require('../src/middleware/error.middleware');
const { makeNullLogger } = require('./test-helpers');
const environment = require('../src/config/environment');

describe('Validation Middleware', () => {
  function buildApp(schema, target = 'body') {
    const app = express();
    app.use(express.json());
    app.post('/test', validate(schema, target), (req, res) => {
      res.status(200).json({ ok: true, validated: req[target] });
    });
    app.use(notFoundMiddleware);
    app.use(errorHandlerMiddleware);
    return app;
  }

  it('passes validated data through for valid body', async () => {
    const schema = z.object({
      email: z.string().email(),
      count: z.coerce.number().int().min(1),
    });
    const app = buildApp(schema, 'body');
    const res = await request(app)
      .post('/test')
      .send({ email: 'hello@example.com', count: '42' });
    expect(res.status).toBe(200);
    expect(res.body.validated.email).toBe('hello@example.com');
    expect(res.body.validated.count).toBe(42);
  });

  it('returns 400 with structured errors for invalid body', async () => {
    const schema = z.object({
      email: z.string().email(),
    });
    const app = buildApp(schema, 'body');
    const res = await request(app)
      .post('/test')
      .send({ email: 'not-an-email' });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
    expect(Array.isArray(res.body.error.errors)).toBe(true);
    expect(res.body.error.errors.length).toBeGreaterThan(0);
    expect(res.body.error.errors[0].message).toBeDefined();
  });

  it('validates query parameters', async () => {
    const schema = z.object({
      page: z.coerce.number().int().min(1).default(1),
    });
    const app = express();
    app.use(express.json());
    app.get('/test', validate(schema, 'query'), (req, res) => {
      res.json({ page: req.query.page });
    });
    app.use(errorHandlerMiddleware);
    const res = await request(app).get('/test?page=5');
    expect(res.status).toBe(200);
    expect(res.body.page).toBe(5);
  });

  it('validates URL params via target=params', async () => {
    const schema = z.object({
      id: z.string().uuid(),
    });
    const app = express();
    app.use(express.json());
    app.get('/test/:id', validate(schema, 'params'), (req, res) => {
      res.json({ id: req.params.id });
    });
    app.use(errorHandlerMiddleware);
    const resOk = await request(app).get('/test/123e4567-e89b-12d3-a456-426614174000');
    expect(resOk.status).toBe(200);
    const resBad = await request(app).get('/test/not-a-uuid');
    expect(resBad.status).toBe(400);
  });
});

describe('Common Validators', () => {
  const { authLoginSchema, authRegisterSchema, paginationQuerySchema, idParamSchema } = require('../src/validators/common.validators');

  it('authLoginSchema rejects bad email and empty password', () => {
    const r1 = authLoginSchema.safeParse({ email: 'bad', password: 'abc' });
    expect(r1.success).toBe(false);
    const r2 = authLoginSchema.safeParse({ email: 'a@b.com', password: '' });
    expect(r2.success).toBe(false);
    const r3 = authLoginSchema.safeParse({ email: 'a@b.com', password: 'okpassword' });
    expect(r3.success).toBe(true);
  });

  it('authRegisterSchema enforces password complexity', () => {
    const weak = authRegisterSchema.safeParse({ email: 'a@b.com', password: 'short' });
    expect(weak.success).toBe(false);
    const noupper = authRegisterSchema.safeParse({ email: 'a@b.com', password: 'password1' });
    expect(noupper.success).toBe(false);
    const good = authRegisterSchema.safeParse({ email: 'a@b.com', password: 'Password1' });
    expect(good.success).toBe(true);
  });

  it('paginationQuerySchema provides defaults', () => {
    const parsed = paginationQuerySchema.parse({});
    expect(parsed.page).toBe(1);
    expect(parsed.limit).toBe(20);
    const tooBig = paginationQuerySchema.safeParse({ limit: 99999 });
    expect(tooBig.success).toBe(false);
  });

  it('idParamSchema requires non-empty string id', () => {
    expect(idParamSchema.safeParse({ id: '' }).success).toBe(false);
    expect(idParamSchema.safeParse({ id: 'abc' }).success).toBe(true);
  });
});
