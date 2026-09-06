'use strict';

const express = require('express');
const compression = require('compression');

const environment = require('./config/environment');
const serverConfig = require('./config/server');
const firebaseConfig = require('./config/firebase');
const smtpConfig = require('./config/smtp');
const storageConfig = require('./config/storage');
const databaseConfig = require('./config/database');
const { store: storeDatabase } = require('./utils/db');

const { logger } = require('./utils/logger');

const buildHelmetMiddleware = require('./middleware/security.middleware');
const buildCorsMiddleware = require('./middleware/cors.middleware');
const { buildGlobalRateLimiter } = require('./middleware/rateLimit.middleware');
const {
  requestIdMiddleware,
  buildMorganMiddleware,
  attachMetadataMiddleware,
} = require('./middleware/logging.middleware');
const {
  errorHandlerMiddleware,
  notFoundMiddleware,
} = require('./middleware/error.middleware');

const { firebaseAdminService } = require('./services/firebase.service');
const { emailService } = require('./services/email.service');
const { storageService } = require('./services/storage.service');
const aiGatewayService = require('./services/ai-gateway.service');
const { optionalAuthentication } = require('./middleware/auth.middleware');
const { resolveTenantContext } = require('./middleware/tenant.middleware');

const { registerApiRoutes } = require('./routes');

function buildServices() {
  try {
    firebaseAdminService.initialize();
  } catch (err) {
    logger.warn({ err }, 'Firebase Admin initialization skipped (non-fatal)');
  }
  try {
    emailService.initialize();
  } catch (err) {
    logger.warn({ err }, 'Email service initialization skipped (non-fatal)');
  }
  try {
    storageService.initialize();
  } catch (err) {
    logger.error({ err }, 'Storage service initialization failed');
    throw err;
  }
  return {
    firebase: firebaseAdminService,
    email: emailService,
    storage: storageService,
    aiGateway: aiGatewayService,
  };
}

function createApp(dependencies = {}) {
  const services = dependencies.services || buildServices();
  const appLogger = dependencies.logger || logger;
  const app = express();

  app.set('trust proxy', serverConfig.trustProxy);
  app.disable('x-powered-by');

  app.use(requestIdMiddleware);
  app.use(attachMetadataMiddleware);
  app.use(buildMorganMiddleware(appLogger));

  app.use(buildHelmetMiddleware());
  app.use(buildCorsMiddleware());
  app.use(buildGlobalRateLimiter());
  app.use(compression({
    level: 6,
    threshold: 1024,
    filter(req, res) {
      if (req.headers['x-no-compression']) return false;
      return compression.filter(req, res);
    },
  }));

  app.use(express.json(serverConfig.json));
  app.use(express.urlencoded(serverConfig.urlencoded));

  app.use(function attachAppContext(req, _res, next) {
    req.services = services;
    req.appLogger = appLogger;
    next();
  });

  // Global Tenant Resolution (resolves business_id if token is present)
  app.use(optionalAuthentication(services.firebase));
  app.use(resolveTenantContext);

  app.get('/', (_req, res) => {
    res.json({
      service: 'jonkstore-backend',
      version: process.env.npm_package_version || '1.0.0',
      status: 'running',
      timestamp: new Date().toISOString(),
    });
  });

  const depSnapshot = {
    firebase: services.firebase,
    email: services.email,
    aiGateway: {
      baseUrl: (services.aiGateway && services.aiGateway.baseUrl) || null,
      isConfigured: Boolean(services.aiGateway),
    },
    storage: {
      uploadRoot: storageConfig.uploadRoot,
      isConfigured: Boolean(services.storage),
    },
    database: {
      // Tests intentionally use no external PostgreSQL dependency.
      isConfigured: environment.isTest ? false : databaseConfig.store.isConfigured,
      host: databaseConfig.store.host || '(unset)',
      name: databaseConfig.store.name || '(unset)',
      ping: () => storeDatabase.query('SELECT 1'),
    },
  };

  registerApiRoutes(app, environment.apiPrefix, depSnapshot);

  app.use(notFoundMiddleware);
  app.use(errorHandlerMiddleware);

  app.locals.services = services;
  app.locals.dependencies = {
    firebaseConfig,
    smtpConfig,
    storageConfig,
    databaseConfig,
    environment,
    serverConfig,
  };

  return app;
}

module.exports = {
  createApp,
  buildServices,
};
