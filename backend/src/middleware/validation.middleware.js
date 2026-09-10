'use strict';

const { ValidationError } = require('../utils/errors');

/**
 * Middleware to validate request parts using Zod schemas.
 * Supports:
 * 1. validate(schema, target) - validates a single target (default 'body')
 * 2. validate({ body: schema, query: schema, ... }) - validates multiple targets
 */
function validate(schemaOrMap, defaultTarget = 'body') {
  return async function validateMiddleware(req, _res, next) {
    try {
      let schemas = {};

      if (schemaOrMap && typeof schemaOrMap.safeParseAsync === 'function') {
        schemas[defaultTarget] = schemaOrMap;
      } else if (typeof schemaOrMap === 'object' && schemaOrMap !== null) {
        schemas = schemaOrMap;
      } else {
        throw new TypeError('validate() requires a Zod schema or a map of schemas');
      }

      for (const [target, schema] of Object.entries(schemas)) {
        if (!['body', 'params', 'query', 'headers'].includes(target)) continue;

        const input = req[target] || {};
        const result = await schema.safeParseAsync(input);

        if (!result.success) {
          const formattedErrors = result.error.issues.map((issue) => ({
            field: issue.path && issue.path.length ? issue.path.join('.') : null,
            message: issue.message,
            code: issue.code,
            target,
          }));

          return next(new ValidationError(
            `Invalid request ${target}`,
            formattedErrors
          ));
        }

        req[target] = result.data;
      }
      return next();
    } catch (err) {
      return next(err);
    }
  };
}

module.exports = {
  validate,
};
