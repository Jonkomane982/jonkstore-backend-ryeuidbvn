'use strict';

const cors = require('cors');
const environment = require('../config/environment');

function buildCorsMiddleware() {
  const { cors: corsConfig } = environment;

  return cors({
    origin(origin, callback) {
      if (!origin) return callback(null, true);
      if (corsConfig.origin.length === 0) {
        return callback(null, true);
      }
      if (corsConfig.origin.includes(origin)) {
        return callback(null, true);
      }
      if (!environment.isProduction) {
        return callback(null, true);
      }
      callback(new Error(`CORS policy: origin ${origin} not allowed`), false);
    },
    credentials: corsConfig.credentials,
    methods: corsConfig.methods,
    allowedHeaders: corsConfig.allowedHeaders,
    exposedHeaders: corsConfig.exposedHeaders,
    maxAge: corsConfig.maxAge,
    optionsSuccessStatus: 204,
    preflightContinue: false,
  });
}

module.exports = buildCorsMiddleware;
