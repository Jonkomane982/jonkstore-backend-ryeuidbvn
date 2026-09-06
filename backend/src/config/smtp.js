'use strict';

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

const smtpConfig = Object.freeze({
  isConfigured: Boolean(
    process.env.SMTP_HOST &&
    process.env.SMTP_USER &&
    process.env.SMTP_PASS
  ),
  host: process.env.SMTP_HOST || '',
  port: parseNumber(process.env.SMTP_PORT, 587),
  secure: parseBoolean(process.env.SMTP_SECURE, parseNumber(process.env.SMTP_PORT, 587) === 465),
  auth: {
    user: process.env.SMTP_USER || '',
    pass: process.env.SMTP_PASS || '',
  },
  pool: true,
  maxConnections: 5,
  maxMessages: 100,
  rateDelta: 1000,
  rateLimit: 10,
  tls: {
    rejectUnauthorized: parseBoolean(process.env.SMTP_TLS_REJECT_UNAUTHORIZED, true),
  },
  defaults: Object.freeze({
    from: {
      name: process.env.SMTP_FROM_NAME || 'JonkStore',
      address: process.env.SMTP_FROM_EMAIL || 'noreply@jonkstore.local',
    },
  }),
  connectionTimeout: 60000,
  greetingTimeout: 30000,
  socketTimeout: 60000,
});

module.exports = smtpConfig;
