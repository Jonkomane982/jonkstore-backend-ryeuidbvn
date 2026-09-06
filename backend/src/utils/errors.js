'use strict';

class AppError extends Error {
  constructor(message, statusCode = 500, code = 'INTERNAL_ERROR') {
    super(message);
    this.name = this.constructor.name;
    this.statusCode = statusCode;
    this.code = code;
    this.isOperational = true;
    Error.captureStackTrace(this, this.constructor);
  }

  toJSON() {
    return {
      error: {
        code: this.code,
        message: this.message,
      },
    };
  }
}

class NotFoundError extends AppError {
  constructor(message = 'Resource not found', code = 'NOT_FOUND') {
    super(message, 404, code);
  }
}

class ValidationError extends AppError {
  constructor(message = 'Validation failed', errors = [], code = 'VALIDATION_ERROR') {
    super(message, 400, code);
    this.errors = Array.isArray(errors) ? errors : [errors];
  }

  toJSON() {
    return {
      error: {
        code: this.code,
        message: this.message,
        errors: this.errors,
      },
    };
  }
}

class AuthenticationError extends AppError {
  constructor(message = 'Authentication required', code = 'AUTHENTICATION_REQUIRED') {
    super(message, 401, code);
  }
}

class AuthorizationError extends AppError {
  constructor(message = 'Forbidden: insufficient permissions', code = 'FORBIDDEN') {
    super(message, 403, code);
  }
}

class DatabaseError extends AppError {
  constructor(message = 'Database error', cause = null, code = 'DATABASE_ERROR') {
    super(message, 500, code);
    if (cause) this.cause = cause;
  }
}

class ConflictError extends AppError {
  constructor(message = 'Resource conflict', code = 'CONFLICT') {
    super(message, 409, code);
  }
}

class TooManyRequestsError extends AppError {
  constructor(message = 'Too many requests', retryAfterMs = 0, code = 'TOO_MANY_REQUESTS') {
    super(message, 429, code);
    this.retryAfterMs = retryAfterMs;
  }
}

class ServiceUnavailableError extends AppError {
  constructor(message = 'Service temporarily unavailable', code = 'SERVICE_UNAVAILABLE', retryAfterMs = 0) {
    super(message, 503, code);
    this.retryAfterMs = retryAfterMs;
  }
}

module.exports = {
  AppError,
  NotFoundError,
  ValidationError,
  AuthenticationError,
  AuthorizationError,
  DatabaseError,
  ConflictError,
  TooManyRequestsError,
  ServiceUnavailableError,
};
