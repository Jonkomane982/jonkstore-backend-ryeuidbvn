'use strict';

const { ValidationError } = require('../utils/errors');

function validate(schema, target = 'body') {
  if (!schema || typeof schema.safeParseAsync !== 'function') {
    throw new TypeError('validate() requires a Zod schema with safeParseAsync');
  }
  if (!['body', 'params', 'query', 'headers'].includes(target)) {
    throw new TypeError(`Invalid validation target: ${target}`);
  }
  return async function validateMiddleware(req, _res, next) {
    try {
      const input = req[target] || {};
      const result = await schema.safeParseAsync(input);
      if (!result.success) {
        const formattedErrors = result.error.issues.map((issue) => ({
          field: issue.path && issue.path.length ? issue.path.join('.') : null,
          message: issue.message,
          code: issue.code,
        }));
        return next(new ValidationError(
          `Invalid request ${target}`,
          formattedErrors
        ));
      }
      req[target] = result.data;
      return next();
    } catch (err) {
      return next(err);
    }
  };
}

module.exports = {
  validate,
};
