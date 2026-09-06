'use strict';

const request = require('supertest');
const { buildTestApp, createTestServer, MockFirebaseService, MockEmailService } = require('./test-helpers');

describe('GET /health', () => {
  let baseUrl;
  let close;

  beforeAll(async () => {
    const firebase = new MockFirebaseService({ configured: false, initialized: true });
    const email = new MockEmailService({ configured: false, initialized: true });
    const { app } = buildTestApp({ firebase, email });
    const server = await createTestServer(app);
    baseUrl = server.baseUrl;
    close = server.close;
  });

  afterAll(async () => {
    if (close) await close();
  });

  it('returns 200 OK with real health payload', async () => {
    const res = await request(baseUrl).get('/api/health');
    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toMatch(/json/);
  });

  it('includes status, timestamp, startedAt fields', async () => {
    const res = await request(baseUrl).get('/api/health');
    expect(res.body.status).toBeDefined();
    expect(['healthy', 'degraded']).toContain(res.body.status);
    expect(res.body.timestamp).toMatch(/^\d{4}-\d{2}-\d{2}T/);
    expect(res.body.startedAt).toMatch(/^\d{4}-\d{2}-\d{2}T/);
  });

  it('includes service metadata (name, version, environment)', async () => {
    const res = await request(baseUrl).get('/api/health');
    expect(res.body.service).toBeDefined();
    expect(res.body.service.name).toBe('jonkstore-backend');
    expect(res.body.service.environment).toBeDefined();
  });

  it('reports uptime in structured format', async () => {
    const res = await request(baseUrl).get('/api/health');
    expect(res.body.uptime).toBeDefined();
    expect(typeof res.body.uptime.totalSeconds).toBe('number');
    expect(res.body.uptime.totalSeconds).toBeGreaterThanOrEqual(0);
    expect(['days', 'hours', 'minutes', 'seconds'].every(
      (k) => typeof res.body.uptime[k] === 'number'
    )).toBe(true);
  });

  it('reports real system info (hostname, node version, pid, memory)', async () => {
    const res = await request(baseUrl).get('/api/health');
    expect(res.body.system.hostname).toBeDefined();
    expect(typeof res.body.system.hostname).toBe('string');
    expect(res.body.system.nodeVersion).toMatch(/^v/);
    expect(typeof res.body.system.pid).toBe('number');
    expect(res.body.system.pid).toBeGreaterThan(0);
    expect(res.body.system.memory.system.total).toBeGreaterThan(0);
  });

  it('reports per-service status for firebase, email, storage, database', async () => {
    const res = await request(baseUrl).get('/api/health');
    expect(res.body.services).toBeDefined();
    expect(res.body.services.firebase).toBeDefined();
    expect(res.body.services.email).toBeDefined();
    expect(res.body.services.storage).toBeDefined();
    expect(res.body.services.database).toBeDefined();
    expect(typeof res.body.services.firebase.configured).toBe('boolean');
    expect(typeof res.body.services.email.configured).toBe('boolean');
  });

  it('reports process checks are true', async () => {
    const res = await request(baseUrl).get('/api/health');
    expect(res.body.checks.process_running).toBe(true);
    expect(res.body.checks.http_ok).toBe(true);
  });
});
