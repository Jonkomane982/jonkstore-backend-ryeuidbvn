'use strict';

const { v4: uuidv4 } = require('uuid');
const morgan = require('morgan');
const environment = require('../config/environment');

function requestIdMiddleware(req, _res, next) {
  const existing = req.headers['x-request-id'];
  req.id = existing || uuidv4();
  _res.setHeader('X-Request-Id', req.id);
  next();
}

function buildMorganMiddleware(logger) {
  const format = environment.isProduction ? 'combined' : 'dev';
  const stream = {
    write(message) {
      const trimmed = message.trimEnd();
      if (trimmed) {
        logger.info({ type: 'http_access' }, trimmed);
      }
    },
  };
  return morgan(format, { stream, immediate: false });
}

function attachMetadataMiddleware(req, _res, next) {
  req.startedAt = Date.now();
  next();
}

module.exports = {
  requestIdMiddleware,
  buildMorganMiddleware,
  attachMetadataMiddleware,
};
