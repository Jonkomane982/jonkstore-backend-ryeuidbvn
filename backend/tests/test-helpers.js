'use strict';

const http = require('http');
const path = require('path');
const { createApp } = require('../src/app');

function makeNullLogger() {
  return {
    info() {},
    warn() {},
    error() {},
    debug() {},
    trace() {},
    fatal() {},
    child() {
      return makeNullLogger();
    },
  };
}

class MockFirebaseService {
  constructor(options = {}) {
    this.configured = options.configured ?? false;
    this.initialized = options.initialized ?? true;
    this.tokenResult = options.tokenResult || null;
    this.tokenError = options.tokenError || null;
    this.calls = [];
  }
  isConfigured() { return this.configured; }
  isInitialized() { return this.initialized; }
  initialize() { return null; }
  async verifyIdToken(token, checkRevoked = false) {
    this.calls.push({ token, checkRevoked });
    if (this.tokenError) throw this.tokenError;
    if (this.tokenResult) return this.tokenResult;
    throw { code: 'auth/invalid-id-token', message: 'invalid' };
  }
}

class MockEmailService {
  constructor(options = {}) {
    this.configured = options.configured ?? false;
    this.initialized = options.initialized ?? true;
    this.sent = [];
  }
  isConfigured() { return this.configured; }
  isInitialized() { return this.initialized; }
  initialize() { return null; }
  async verifyConnection() { return this.configured; }
  async sendEmail(options) {
    this.sent.push(options);
    return { messageId: `mock-${Date.now()}`, accepted: options.to, rejected: [], captured: true };
  }
  getCapturedEmails() { return [...this.sent]; }
  shutdown() { return null; }
}

class MockStorageService {
  constructor(options = {}) {
    this.uploadRoot = options.uploadRoot || '/tmp/jonkstore-test-uploads';
    this.initialized = true;
  }
  initialize() { return null; }
  resolveCategoryDir(category) {
    return path.join(this.uploadRoot, category);
  }
  single(category, field = 'file') {
    return (_req, _res, next) => next();
  }
  array(category, field = 'files') {
    return (_req, _res, next) => next();
  }
}

function buildTestApp(overrides = {}) {
  const services = overrides.services || {
    firebase: overrides.firebase || new MockFirebaseService(),
    email: overrides.email || new MockEmailService(),
    storage: overrides.storage || new MockStorageService(),
  };
  const app = createApp({
    services,
    logger: makeNullLogger(),
  });
  return { app, services };
}

function createTestServer(app) {
  return new Promise((resolve, reject) => {
    const server = http.createServer(app);
    server.listen(0, '127.0.0.1', (err) => {
      if (err) return reject(err);
      const addr = server.address();
      resolve({
        server,
        baseUrl: `http://127.0.0.1:${addr.port}`,
        port: addr.port,
        close() {
          return new Promise((r) => server.close(() => r()));
        },
      });
    });
  });
}

module.exports = {
  makeNullLogger,
  MockFirebaseService,
  MockEmailService,
  MockStorageService,
  buildTestApp,
  createTestServer,
};
