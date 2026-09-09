'use strict';

const path = require('path');
const dotenv = require('dotenv');
const pino = require('pino');

const testEnvFile = path.resolve(process.cwd(), '.env.test');
dotenv.config({ path: testEnvFile, override: false });

process.env.NODE_ENV = process.env.NODE_ENV || 'test';
process.env.PORT = process.env.PORT || '0';
process.env.LOG_LEVEL = process.env.LOG_LEVEL || 'fatal';
process.env.LOG_PRETTY = 'false';
process.env.OWNER_EMAIL = process.env.OWNER_EMAIL || 'owner@test.local';

const silentLogger = pino({
  level: 'silent',
  timestamp: false,
}, pino.destination({ sync: false }));

global.__TEST_LOGGER__ = silentLogger;

jest.setTimeout(15000);
