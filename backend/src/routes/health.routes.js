'use strict';

const express = require('express');
const { getHealthCheck } = require('../controllers/health.controller');

function buildHealthRouter(dependencies = {}) {
  const router = express.Router();
  router.get('/', getHealthCheck(dependencies));
  return router;
}

module.exports = { buildHealthRouter };
