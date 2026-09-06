'use strict';

const crypto = require('crypto');

/**
 * Deterministically stringifies a JSON object.
 */
function canonicalizeJson(obj) {
  if (obj === null || typeof obj !== 'object') {
    return JSON.stringify(obj);
  }

  if (Array.isArray(obj)) {
    return '[' + obj.map(canonicalizeJson).join(',') + ']';
  }

  const keys = Object.keys(obj).sort();
  return '{' + keys.map(k => `${JSON.stringify(k)}:${canonicalizeJson(obj[k])}`).join(',') + '}';
}

/**
 * Generates a SHA-256 hash of a JSON object.
 */
function hashPayload(payload) {
  const canonical = canonicalizeJson(payload);
  return crypto.createHash('sha256').update(canonical).digest('hex');
}

/**
 * Wraps an async function to catch errors and pass them to express error middleware.
 */
function asyncHandler(fn) {
  return function(req, res, next) {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}

/**
 * Generates a cryptographically secure 6-digit OTP.
 */
function generateOtp() {
  return crypto.randomInt(100000, 999999).toString();
}

module.exports = {
  canonicalizeJson,
  hashPayload,
  asyncHandler,
  generateOtp,
};
