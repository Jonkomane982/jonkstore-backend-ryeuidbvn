'use strict';

const request = require('supertest');
const { buildTestApp, createTestServer } = require('./test-helpers');

describe('Server Startup', () => {
  it('creates an express app without throwing', () => {
    expect(() => buildTestApp()).not.toThrow();
  });

  it('can boot a real HTTP server on a random port', async () => {
    const { app } = buildTestApp();
    const { server, close, baseUrl } = await createTestServer(app);
    try {
      expect(server).toBeDefined();
      expect(baseUrl).toMatch(/^http:\/\/127\.0\.0\.1:\d+$/);
      const res = await request(baseUrl).get('/');
      expect(res.status).toBe(200);
      expect(res.body.service).toBe('jonkstore-backend');
      expect(res.body.status).toBe('running');
    } finally {
      await close();
    }
  }, 20000);

  it('exposes x-request-id on responses', async () => {
    const { app } = buildTestApp();
    const { close, baseUrl } = await createTestServer(app);
    try {
      const res = await request(baseUrl).get('/');
      expect(res.headers['x-request-id']).toBeDefined();
      expect(typeof res.headers['x-request-id']).toBe('string');
      expect(res.headers['x-request-id'].length).toBeGreaterThan(0);
    } finally {
      await close();
    }
  });

  it('preserves user-provided x-request-id if sent', async () => {
    const { app } = buildTestApp();
    const { close, baseUrl } = await createTestServer(app);
    try {
      const sentId = 'test-request-id-12345';
      const res = await request(baseUrl)
        .get('/')
        .set('X-Request-Id', sentId);
      expect(res.headers['x-request-id']).toBe(sentId);
    } finally {
      await close();
    }
  });
});
