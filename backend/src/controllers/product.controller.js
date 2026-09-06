'use strict';

const { asyncHandler } = require('../utils/helpers');
const aiPipeline = require('../services/ai-data-pipeline.service');
const { logger } = require('../utils/logger');

/**
 * Handles Product synchronization and operational logic.
 * Integrates with JONK AI Data Pipeline.
 */
class ProductController {
  /**
   * Syncs a product from the POS.
   */
  syncProduct = asyncHandler(async (req, res) => {
    const productData = req.body;
    const { operation } = req.query; // CREATE, UPDATE, DELETE

    logger.info({ productId: productData.id, operation }, 'Syncing product');

    // 1. Operational Persistence (Firestore/Firebase)
    // Note: For now, we assume the Firebase service handles the operational mirror.
    if (req.services.firebase) {
      await req.services.firebase.upsert('products', productData.id, productData);
    }

    // 2. AI Data Foundation Mirroring
    // We pass the event to the pipeline. It will handle the PostgreSQL mirror.
    await aiPipeline.processSyncEvent('products', operation || 'UPSERT', productData);

    res.status(200).json({
      success: true,
      message: 'Product synced and mirrored to AI database',
      serverId: productData.id,
      timestamp: new Date().toISOString(),
    });
  });

  getAll = asyncHandler(async (req, res) => {
    // Standard implementation for operational retrieval
    res.status(200).json({ success: true, data: [] });
  });
}

module.exports = new ProductController();
