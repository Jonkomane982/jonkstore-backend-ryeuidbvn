'use strict';

const express = require('express');
const { createNotImplementedHandler } = require('../controllers/common.controller');

const MODULE_NAME = 'Inventory';
const ROUTES = [
  { method: 'GET', path: '/' },
  { method: 'GET', path: '/:id' },
  { method: 'POST', path: '/adjustments' },
  { method: 'POST', path: '/counts' },
  { method: 'GET', path: '/transactions' },
  { method: 'POST', path: '/transfers' },
];

function buildInventoryRouter() {
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

module.exports = { buildInventoryRouter };
