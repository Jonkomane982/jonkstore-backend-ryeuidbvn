'use strict';

const path = require('path');

const ENV_FILE = path.resolve(process.cwd(), '.env');
require('dotenv').config({ path: ENV_FILE });

const NODE_ENV = process.env.NODE_ENV || 'development';
const isProduction = NODE_ENV === 'production';
const isDevelopment = NODE_ENV === 'development';
const isTest = NODE_ENV === 'test';

function parseBoolean(value, fallback = false) {
  if (value === undefined || value === null || value === '') return fallback;
  const normalized = String(value).trim().toLowerCase();
  if (['true', '1', 'yes', 'on'].includes(normalized)) return true;
  if (['false', '0', 'no', 'off'].includes(normalized)) return false;
  return fallback;
}

function parseNumber(value, fallback) {
  const num = Number(value);
  return Number.isFinite(num) ? num : fallback;
}

function parseCsvList(value) {
  if (!value) return [];
  return String(value)
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
}

const environment = Object.freeze({
  nodeEnv: NODE_ENV,
  isProduction,
  isDevelopment,
  isTest,
  apiPrefix: process.env.API_PREFIX || '/api',

  server: Object.freeze({
    host: process.env.HOST || '0.0.0.0',
    port: parseNumber(process.env.PORT, 3000),
    requestBodyLimit: process.env.REQUEST_BODY_LIMIT || '10mb',
  }),

  cors: Object.freeze({
    origin: parseCsvList(process.env.CORS_ORIGIN),
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: [
      'Content-Type',
      'Authorization',
      'X-Request-Id',
      'X-Firebase-AppCheck',
    ],
    exposedHeaders: ['X-Request-Id'],
    maxAge: 86400,
  }),

  rateLimit: Object.freeze({
    windowMs: parseNumber(process.env.RATE_LIMIT_WINDOW_MS, 15 * 60 * 1000),
    max: parseNumber(process.env.RATE_LIMIT_MAX_REQUESTS, 1000),
    standardHeaders: true,
    legacyHeaders: false,
    skipSuccessfulRequests: false,
    skipFailedRequests: false,
  }),

  logging: Object.freeze({
    level: process.env.LOG_LEVEL || (isProduction ? 'info' : 'debug'),
    pretty: parseBoolean(process.env.LOG_PRETTY, !isProduction),
  }),

  security: Object.freeze({
    jwtSecret: process.env.JWT_SECRET || '',
    bcryptRounds: parseNumber(process.env.BCRYPT_ROUNDS, 12),
    exposeStackTraces: !isProduction,
  }),

  smtp: Object.freeze({
    host: process.env.SMTP_HOST || '',
    port: parseNumber(process.env.SMTP_PORT, 587),
    secure: parseBoolean(process.env.SMTP_SECURE, parseNumber(process.env.SMTP_PORT, 587) === 465),
    user: process.env.SMTP_USER || '',
    pass: process.env.SMTP_PASS || '',
    fromName: process.env.SMTP_FROM_NAME || 'JonkStore',
    fromEmail: process.env.SMTP_FROM_EMAIL || 'noreply@jonkstore.local',
    tlsRejectUnauthorized: parseBoolean(process.env.SMTP_TLS_REJECT_UNAUTHORIZED, true),
  }),

  firebase: Object.freeze({
    projectId: process.env.FIREBASE_PROJECT_ID || '',
    clientEmail: process.env.FIREBASE_CLIENT_EMAIL || '',
    privateKey: process.env.FIREBASE_PRIVATE_KEY || '',
    privateKeyBase64: process.env.FIREBASE_PRIVATE_KEY_BASE64 || '',
    serviceAccountBase64: process.env.FIREBASE_SERVICE_ACCOUNT_BASE64 || '',
    storageBucket: process.env.FIREBASE_STORAGE_BUCKET || '',
  }),

  ownerEmail: (process.env.OWNER_EMAIL || '').trim().toLowerCase(),
});

function validateProductionEnvironment() {
  if (!isProduction) return;
  const required = [
    ['OWNER_EMAIL', environment.ownerEmail],
    ['FIREBASE_PROJECT_ID', environment.firebase.projectId],
    ['FIREBASE_CLIENT_EMAIL', environment.firebase.clientEmail],
    ['FIREBASE_PRIVATE_KEY (or Base64)',
      environment.firebase.privateKey ||
      environment.firebase.privateKeyBase64 ||
      environment.firebase.serviceAccountBase64],
    ['DB_STORE_URL or Host', process.env.DB_STORE_URL || process.env.DB_STORE_HOST],
    ['DB_AI_URL or Host', process.env.DB_AI_URL || process.env.DB_AI_HOST],
  ];
  const missing = required.filter(([, value]) => !value).map(([name]) => name);
  if (missing.length) {
    throw new Error(`Missing required production environment variables: ${missing.join(', ')}`);
  }
}

module.exports = Object.freeze({ ...environment, validateProductionEnvironment });
