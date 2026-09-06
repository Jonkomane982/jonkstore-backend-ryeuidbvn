'use strict';

const { buildHealthRouter } = require('./health.routes');
const { buildAuthRouter } = require('./auth.routes');
const { buildBusinessesRouter } = require('./businesses.routes');
const { buildProductsRouter } = require('./products.routes');
const { buildInventoryRouter } = require('./inventory.routes');
const { buildPurchasesRouter } = require('./purchases.routes');
const { buildCustomersRouter } = require('./customers.routes');
const { buildSalesRouter } = require('./sales.routes');
const { buildPaymentsRouter } = require('./payments.routes');
const { buildReportsRouter } = require('./reports.routes');
const { buildNotificationsRouter } = require('./notifications.routes');
const { buildJonkaiRouter } = require('./jonkai.routes');

function registerApiRoutes(app, apiPrefix, dependencies) {
  app.use(`${apiPrefix}/health`, buildHealthRouter(dependencies));
  app.use(`${apiPrefix}/auth`, buildAuthRouter());
  app.use(`${apiPrefix}/businesses`, buildBusinessesRouter());
  app.use(`${apiPrefix}/products`, buildProductsRouter());
  app.use(`${apiPrefix}/inventory`, buildInventoryRouter());
  app.use(`${apiPrefix}/purchases`, buildPurchasesRouter());
  app.use(`${apiPrefix}/customers`, buildCustomersRouter());
  app.use(`${apiPrefix}/sales`, buildSalesRouter());
  app.use(`${apiPrefix}/payments`, buildPaymentsRouter());
  app.use(`${apiPrefix}/reports`, buildReportsRouter());
  app.use(`${apiPrefix}/notifications`, buildNotificationsRouter());

  // JONK AI Ingestion & Analytics Gateway
  app.use(`${apiPrefix}/jonkai`, buildJonkaiRouter());
}

module.exports = {
  registerApiRoutes,
};
