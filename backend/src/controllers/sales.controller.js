'use strict';

const { asyncHandler } = require('../utils/helpers');
const aiPipeline = require('../services/ai-data-pipeline.service');
const { logger } = require('../utils/logger');

/**
 * Handles Sales synchronization and operational logic.
 * Integrates with JONK AI Data Pipeline.
 */
class SalesController {
  /**
   * Syncs a sale from the POS.
   */
  syncSale = asyncHandler(async (req, res) => {
    const saleData = req.body;
    const { operation } = req.query; // Usually CREATE for sales

    logger.info({ saleId: saleData.id, operation }, 'Syncing sale');

    // 1. Operational Persistence (Firestore/Firebase)
    if (req.services.firebase) {
      await req.services.firebase.upsert('sales', saleData.id, saleData);
    }

    // 2. AI Data Foundation Mirroring
    // We pass the event to the pipeline.
    // The pipeline handles inserting into PostgreSQL ai_sales and ai_sale_items.
    await aiPipeline.processSyncEvent('sales', operation || 'CREATE', saleData);

    res.status(200).json({
      success: true,
      message: 'Sale synced and mirrored to AI database',
      serverId: saleData.id,
      timestamp: new Date().toISOString(),
    });
  });

  getById = asyncHandler(async (req, res) => {
    res.status(200).json({ success: true, data: {} });
  });
}

module.exports = new SalesController();
