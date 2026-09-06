'use strict';

const os = require('os');
const { asyncHandler } = require('../utils/helpers');

const startedAt = new Date().toISOString();

function formatUptime(seconds) {
  const days = Math.floor(seconds / 86400);
  const hours = Math.floor((seconds % 86400) / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = Math.floor(seconds % 60);
  return { days, hours, minutes, seconds: secs, totalSeconds: Math.floor(seconds) };
}

function getMemoryInfo() {
  const usage = process.memoryUsage();
  return {
    rss: usage.rss,
    heapUsed: usage.heapUsed,
    heapTotal: usage.heapTotal,
    external: usage.external,
    arrayBuffers: usage.arrayBuffers || 0,
  };
}

function getHealthCheck(dependencies) {
  return asyncHandler(async function getHealthHandler(req, res) {
    const now = Date.now();
    const uptimeSeconds = process.uptime();
    const loadAvg = os.loadavg();

    const services = {
      firebase: {
        status: 'unknown',
        configured: dependencies && dependencies.firebase ? dependencies.firebase.isConfigured() : false,
        initialized: dependencies && dependencies.firebase ? dependencies.firebase.isInitialized() : false,
      },
      email: {
        status: 'unknown',
        configured: dependencies && dependencies.email ? dependencies.email.isConfigured() : false,
        initialized: dependencies && dependencies.email ? dependencies.email.isInitialized() : false,
      },
      database: {
        status: 'unknown',
        configured: dependencies && dependencies.database ? dependencies.database.isConfigured : false,
      },
      storage: {
        status: 'operational',
        root: dependencies && dependencies.storage ? dependencies.storage.uploadRoot : null,
      },
    };

    if (dependencies && dependencies.email && dependencies.email.isInitialized()) {
      try {
        services.email.status = dependencies.email.isConfigured() ? 'operational' : 'bypass';
      } catch {
        services.email.status = 'degraded';
      }
    } else if (dependencies && dependencies.email && !dependencies.email.isConfigured()) {
      services.email.status = 'unconfigured';
    }

    if (dependencies && dependencies.firebase && dependencies.firebase.isInitialized()) {
      services.firebase.status = dependencies.firebase.isConfigured() ? 'operational' : 'bypass';
    } else if (dependencies && dependencies.firebase && !dependencies.firebase.isConfigured()) {
      services.firebase.status = 'unconfigured';
    }

    if (!services.database.configured) {
      services.database.status = 'unconfigured';
    } else if (dependencies.database && typeof dependencies.database.ping === 'function') {
      try {
        await dependencies.database.ping();
        services.database.status = 'operational';
      } catch {
        services.database.status = 'degraded';
      }
    }

    const overallStatus = Object.values(services).every(
      (svc) => svc.status === 'operational' || svc.status === 'bypass' || svc.status === 'unconfigured'
    )
      ? 'healthy'
      : 'degraded';

    const httpCode = overallStatus === 'healthy' ? 200 : 503;

    const response = {
      status: overallStatus,
      timestamp: new Date(now).toISOString(),
      startedAt,
      uptime: formatUptime(uptimeSeconds),
      requestId: req.id || null,
      service: {
        name: 'jonkstore-backend',
        version: process.env.npm_package_version || '1.0.0',
        environment: process.env.NODE_ENV || 'development',
      },
      system: {
        hostname: os.hostname(),
        platform: process.platform,
        nodeVersion: process.version,
        arch: process.arch,
        pid: process.pid,
        cpus: os.cpus().length,
        loadAverage: {
          '1m': Number(loadAvg[0].toFixed(2)),
          '5m': Number(loadAvg[1].toFixed(2)),
          '15m': Number(loadAvg[2].toFixed(2)),
        },
        memory: {
          process: getMemoryInfo(),
          system: {
            free: os.freemem(),
            total: os.totalmem(),
            usedPercent: Number(((os.totalmem() - os.freemem()) / os.totalmem() * 100).toFixed(1)),
          },
        },
      },
      services,
      checks: {
        process_running: true,
        http_ok: true,
      },
    };

    res.status(httpCode).json(response);
  });
}

module.exports = {
  getHealthCheck,
};
