'use strict';

const express = require('express');
const { createNotImplementedHandler } = require('../controllers/common.controller');

const MODULE_NAME = 'Payments';
const ROUTES = [
  { method: 'GET', path: '/' },
  { method: 'POST', path: '/' },
  { method: 'GET', path: '/:id' },
  { method: 'PATCH', path: '/:id/status' },
  { method: 'POST', path: '/:id/refund' },
];

function buildPaymentsRouter() {
  const router = express.Router();
  for (const r of ROUTES) {
    const handler = createNotImplementedHandler(MODULE_NAME, r);
    switch (r.method) {
      case 'GET': router.get(r.path, handler); break;
      case 'POST': router.post(r.path, handler); break;
      case 'PUT': router.put(r.path, handler); break;
      case 'PATCH': router.patch(r.path, handler); break;
      case 'DELETE': router.delete(r.path, handler); break;
    }
  }
  return router;
}

module.exports = { buildPaymentsRouter };
