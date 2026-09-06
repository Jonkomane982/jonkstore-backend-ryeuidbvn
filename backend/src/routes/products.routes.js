'use strict';

const express = require('express');
const { createNotImplementedHandler } = require('../controllers/common.controller');

const MODULE_NAME = 'Products';
const ROUTES = [
  { method: 'GET', path: '/' },
  { method: 'POST', path: '/' },
  { method: 'GET', path: '/:id' },
  { method: 'PUT', path: '/:id' },
  { method: 'PATCH', path: '/:id' },
  { method: 'DELETE', path: '/:id' },
  { method: 'POST', path: '/:id/images' },
  { method: 'DELETE', path: '/:id/images/:imageId' },
];

function buildProductsRouter() {
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

module.exports = { buildProductsRouter };
