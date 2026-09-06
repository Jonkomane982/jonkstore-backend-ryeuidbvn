'use strict';

const pino = require('pino');
const environment = require('../config/environment');

const redactPaths = [
  'req.headers.authorization',
  'req.headers.cookie',
  'req.headers["x-firebase-appcheck"]',
  'req.body.password',
  'req.body.confirmPassword',
  'req.body.oldPassword',
  'req.body.newPassword',
  'req.body.token',
  'req.body.otp',
  'req.body.refreshToken',
  'req.body.smtp_pass',
  'req.body.apiKey',
  'req.body.secret',
  'res.headers["set-cookie"]',
  'password',
  'privateKey',
  'secret',
  'apiKey',
  'token',
  'otp',
];

const pinoOptions = {
  level: environment.logging.level,
  name: 'jonkstore-backend',
  timestamp: pino.stdTimeFunctions.isoTime,
  redact: {
    paths: redactPaths,
    censor: '[REDACTED]',
  },
  serializers: {
    err: pino.stdSerializers.err,
    req: (req) => ({
      id: req.id,
      method: req.method,
      url: req.url,
      headers: req.headers,
      remoteAddress: req.remoteAddress,
    }),
    res: pino.stdSerializers.res,
  },
  base: {
    service: 'jonkstore-backend',
    env: environment.nodeEnv,
  },
};

if (environment.logging.pretty && !environment.isProduction) {
  let havePinoPretty = false;
  try {
    require.resolve('pino-pretty');
    havePinoPretty = true;
  } catch (_e) {
    havePinoPretty = false;
  }
  if (havePinoPretty) {
    pinoOptions.transport = {
      target: 'pino-pretty',
      options: {
        colorize: true,
        translateTime: 'SYS:standard',
        ignore: 'pid,hostname,service,env',
      },
    };
  }
}

const logger = pino(pinoOptions);

function childLogger(bindings) {
  return logger.child(bindings || {});
}

module.exports = {
  logger,
  childLogger,
};
