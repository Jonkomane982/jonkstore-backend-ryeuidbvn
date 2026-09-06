'use strict';

process.on('uncaughtException', (err) => {
  console.error('UNCAUGHT EXCEPTION:', err && err.stack ? err.stack : err);
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error(
    'UNHANDLED REJECTION at:',
    promise,
    'reason:',
    reason && reason.stack ? reason.stack : reason
  );
  process.exit(1);
});

const { createApp, buildServices } = require('./app');
const serverConfig = require('./config/server');
const environment = require('./config/environment');
const { logger } = require('./utils/logger');
const { firebaseAdminService } = require('./services/firebase.service');
const { emailService } = require('./services/email.service');

let server = null;
let shuttingDown = false;
const startupLogger = logger.child({ phase: 'startup' });

function buildServer() {
  const services = buildServices();
  const app = createApp({ services });
  server = require('http').createServer(app);

  server.keepAliveTimeout = serverConfig.keepAliveTimeout;
  server.headersTimeout = serverConfig.headersTimeout;

  return { server, app, services };
}

function startServer() {
  return new Promise((resolve, reject) => {
    try {
      environment.validateProductionEnvironment();
    } catch (err) {
      reject(err);
      return;
    }
    const { server: httpServer, app } = buildServer();

    httpServer.once('error', (err) => {
      if (err.code === 'EADDRINUSE') {
        startupLogger.error(
          { port: serverConfig.port, host: serverConfig.host },
          `Port ${serverConfig.port} is already in use`
        );
      } else {
        startupLogger.error({ err }, 'Server failed to start');
      }
      reject(err);
    });

    httpServer.listen({
      port: serverConfig.port,
      host: serverConfig.host,
    }, () => {
      const addr = httpServer.address();
      const host = addr.address === '::' || addr.address === '0.0.0.0' ? 'localhost' : addr.address;
      const baseUrl = `http://${host}:${addr.port}`;
      startupLogger.info(
        {
          port: addr.port,
          host: addr.address,
          env: environment.nodeEnv,
          pid: process.pid,
          baseUrl,
          healthUrl: `${baseUrl}${environment.apiPrefix}/health`,
        },
        `JonkStore backend listening on ${baseUrl} (env=${environment.nodeEnv})`
      );
      resolve({ server: httpServer, app, baseUrl, addr });
    });
  });
}

function shutdown(signal) {
  if (shuttingDown) return;
  shuttingDown = true;
  const shutdownLogger = logger.child({ phase: 'shutdown', signal });
  shutdownLogger.info(`Received ${signal}, initiating graceful shutdown...`);

  const forceExitTimer = setTimeout(() => {
    shutdownLogger.error('Graceful shutdown timed out; forcing exit');
    process.exit(1);
  }, serverConfig.shutdownGracePeriodMs);
  forceExitTimer.unref();

  const tasks = [];

  if (server && typeof server.close === 'function') {
    tasks.push(new Promise((resolve) => {
      server.close((err) => {
        if (err) {
          shutdownLogger.warn({ err }, 'Error closing HTTP server');
        } else {
          shutdownLogger.info('HTTP server closed');
        }
        resolve();
      });
    }));
  }

  if (typeof firebaseAdminService !== 'undefined' && firebaseAdminService) {
    // Firebase admin SDK has no explicit close/terminate for normal use
  }

  if (typeof emailService !== 'undefined' && emailService && typeof emailService.shutdown === 'function') {
    tasks.push(Promise.resolve().then(() => emailService.shutdown()));
  }

  Promise.allSettled(tasks).finally(() => {
    clearTimeout(forceExitTimer);
    shutdownLogger.info('Graceful shutdown complete');
    process.exit(0);
  });
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

if (require.main === module) {
  startServer().catch((err) => {
    startupLogger.error({ err }, 'Failed to start server');
    process.exit(1);
  });
}

module.exports = {
  startServer,
  buildServer,
};
