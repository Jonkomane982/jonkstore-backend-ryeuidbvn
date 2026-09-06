'use strict';

const express = require('express');
const { createNotImplementedHandler } = require('../controllers/common.controller');

const MODULE_NAME = 'Notifications';
const ROUTES = [
  { method: 'GET', path: '/' },
  { method: 'POST', path: '/:id/read' },
  { method: 'POST', path: '/read-all' },
  { method: 'DELETE', path: '/:id' },
  { method: 'GET', path: '/settings' },
  { method: 'PUT', path: '/settings' },
];

function buildNotificationsRouter() {
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

module.exports = { buildNotificationsRouter };
