'use strict';

const rateLimit = require('express-rate-limit');
const environment = require('../config/environment');
const { TooManyRequestsError } = require('../utils/errors');

function buildGlobalRateLimiter() {
  const config = environment.rateLimit;
  return rateLimit({
    windowMs: config.windowMs,
    max: config.max,
    standardHeaders: config.standardHeaders,
    legacyHeaders: config.legacyHeaders,
    skipSuccessfulRequests: config.skipSuccessfulRequests,
    skipFailedRequests: config.skipFailedRequests,
    keyGenerator(req) {
      const forwarded = req.headers['x-forwarded-for'];
      const ip = Array.isArray(forwarded)
        ? forwarded[0]
        : forwarded
          ? forwarded.split(',')[0].trim()
          : (req.ip || req.socket.remoteAddress || 'unknown');
      return `${ip}`;
    },
    handler(_req, _res, next) {
      next(new TooManyRequestsError(
        'Rate limit exceeded. Please try again later.',
        environment.rateLimit.windowMs
      ));
    },
    skip(req) {
      return req.originalUrl.startsWith(`${environment.apiPrefix}/health`);
    },
  });
}

function buildStrictRateLimiter(maxRequests = 5, windowMs = 60 * 1000) {
  return rateLimit({
    windowMs,
    max: maxRequests,
    standardHeaders: true,
    legacyHeaders: false,
    keyGenerator(req) {
      const forwarded = req.headers['x-forwarded-for'];
      const ip = Array.isArray(forwarded)
        ? forwarded[0]
        : forwarded
          ? forwarded.split(',')[0].trim()
          : (req.ip || req.socket.remoteAddress || 'unknown');
      return `${ip}:${req.originalUrl}`;
    },
    handler(_req, _res, next) {
      next(new TooManyRequestsError('Rate limit exceeded for sensitive endpoint', windowMs));
    },
  });
}

module.exports = {
  buildGlobalRateLimiter,
  buildStrictRateLimiter,
};
