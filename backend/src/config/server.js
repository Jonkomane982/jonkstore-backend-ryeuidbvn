'use strict';

const environment = require('./environment');

const serverConfig = Object.freeze({
  host: environment.server.host,
  port: environment.server.port,
  apiPrefix: environment.apiPrefix,
  requestBodyLimit: environment.server.requestBodyLimit,
  json: {
    limit: environment.server.requestBodyLimit,
    strict: true,
    type: ['application/json', 'application/*+json'],
  },
  urlencoded: {
    extended: true,
    limit: environment.server.requestBodyLimit,
    parameterLimit: 1000,
  },
  trustProxy: environment.isProduction ? 1 : false,
  shutdownGracePeriodMs: 30000,
  keepAliveTimeout: 65000,
  headersTimeout: 66000,
});

module.exports = serverConfig;
