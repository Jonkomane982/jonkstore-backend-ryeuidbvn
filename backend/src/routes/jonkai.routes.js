'use strict';

const express = require('express');
const jonkaiController = require('../controllers/jonkai.controller');
const { requireAuthentication, requireRole } = require('../middleware/auth.middleware');
const { firebaseAdminService } = require('../services/firebase.service');

/**
 * Routes for JonkAI Ingestion & Analytical Gateway.
 */
function buildJonkaiRouter() {
  const router = express.Router();
  const auth = requireAuthentication(firebaseAdminService);
  const ownerOnly = requireRole('OWNER', 'owner', 'ADMIN', 'admin');

  // Ingestion Endpoints (Usually called by internal services or authorized sync clients)
  router.post('/ingest', auth, ownerOnly, jonkaiController.ingestEvent);
  router.post('/ingest/batch', auth, ownerOnly, jonkaiController.ingestBatch);

  return router;
}

module.exports = {
  buildJonkaiRouter,
};
