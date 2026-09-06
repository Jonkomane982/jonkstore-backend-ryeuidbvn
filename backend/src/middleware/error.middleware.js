'use strict';

const environment = require('../config/environment');
const { logger } = require('../utils/logger');
const {
  AppError,
  ValidationError,
  NotFoundError,
  AuthenticationError,
  AuthorizationError,
  DatabaseError,
} = require('../utils/errors');

function extractZodErrors(zodError) {
  if (!zodError || !zodError.issues) return [];
  return zodError.issues.map((issue) => ({
    field: issue.path && issue.path.length ? issue.path.join('.') : null,
    message: issue.message,
    code: issue.code,
  }));
}

function formatZodError(err) {
  const errors = extractZodErrors(err);
  return new ValidationError('Request validation failed', errors);
}

function errorHandlerMiddleware(err, req, res, _next) {
  const requestId = req.id || 'unknown';

  if (err && err.name === 'ZodError') {
    err = formatZodError(err);
  }

  if (err && err.type === 'entity.too.large') {
    err = new AppError('Request body too large', 413, 'PAYLOAD_TOO_LARGE');
  }

  if (err && err.type === 'entity.parse.failed') {
    err = new AppError('Invalid JSON payload', 400, 'INVALID_JSON');
  }

  if (err && err.code === 'LIMIT_FILE_SIZE') {
    err = new AppError('File size exceeds limit', 413, 'FILE_TOO_LARGE');
  }

  if (err && err.code === 'LIMIT_UNEXPECTED_FILE') {
    err = new AppError('Unexpected file field', 400, 'UNEXPECTED_FILE');
  }

  if (!err || !(err instanceof AppError)) {
    const originalMessage = err && err.message ? err.message : 'An unexpected error occurred';
    logger.error(
      { err, requestId, method: req.method, url: req.originalUrl },
      `Unhandled error: ${originalMessage}`
    );
    const internal = new AppError(
      environment.isProduction ? 'Internal server error' : originalMessage,
      500,
      'INTERNAL_ERROR'
    );
    err = internal;
  }

  if (err.statusCode >= 500) {
    logger.error(
      { err, requestId, method: req.method, url: req.originalUrl },
      `Server error (${err.statusCode}): ${err.message}`
    );
  } else if (err instanceof ValidationError) {
    logger.warn(
      { err: err.toJSON(), requestId, method: req.method, url: req.originalUrl },
      `Validation error: ${err.message}`
    );
  } else {
    logger.info(
      { err: err.toJSON(), requestId, method: req.method, url: req.originalUrl },
      `Operational error (${err.statusCode}): ${err.message}`
    );
  }

  res.status(err.statusCode);

  const responseBody = err.toJSON();

  if (environment.security.exposeStackTraces && err.stack) {
    responseBody.error.stack = err.stack.split('\n');
  }

  responseBody.error.requestId = requestId;
  responseBody.error.timestamp = new Date().toISOString();

  if (err instanceof NotFoundError && !res.headersSent) {
    return res.json(responseBody);
  }

  if (!res.headersSent) {
    return res.json(responseBody);
  }
}

function notFoundMiddleware(req, _res, next) {
  next(new NotFoundError(`Route ${req.method} ${req.originalUrl} does not exist`, 'ROUTE_NOT_FOUND'));
}

module.exports = {
  errorHandlerMiddleware,
  notFoundMiddleware,
};
