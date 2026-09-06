'use strict';

const { asyncHandler } = require('../utils/helpers');
const { AppError } = require('../utils/errors');

function createNotImplementedHandler(moduleName, routeInfo) {
  return asyncHandler(async function notImplementedHandler(_req, _res) {
    throw new AppError(
      `${moduleName} module is not yet implemented. Route: ${routeInfo.method} ${routeInfo.path}`,
      501,
      'NOT_IMPLEMENTED'
    );
  });
}

module.exports = {
  createNotImplementedHandler,
};
