'use strict';

const express = require('express');
const { createNotImplementedHandler } = require('../controllers/common.controller');

const MODULE_NAME = 'Reports';
const ROUTES = [
  { method: 'GET', path: '/dashboard' },
  { method: 'GET', path: '/sales' },
  { method: 'GET', path: '/inventory' },
  { method: 'GET', path: '/customers' },
  { method: 'GET', path: '/purchases' },
  { method: 'GET', path: '/products' },
  { method: 'GET', path: '/export/:type' },
];

function buildReportsRouter() {
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

module.exports = { buildReportsRouter };
