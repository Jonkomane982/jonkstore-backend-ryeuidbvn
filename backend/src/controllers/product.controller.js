'use strict';

const { asyncHandler } = require('../utils/helpers');
const aiPipeline = require('../services/ai-data-pipeline.service');
const productRepository = require('../repositories/product.repository');
const { logger } = require('../utils/logger');

/**
 * Handles Product synchronization and operational logic.
 */
class ProductController {
  /**
   * Syncs a product from the POS to PostgreSQL, Firebase, and JonkAI.
   */
  syncProduct = asyncHandler(async (req, res) => {
    const productData = req.body;
    const { operation } = req.query;

    logger.info({ productId: productData.id, operation }, 'Syncing product');

    // 1. Operational Persistence (PostgreSQL - The source of truth)
    const product = await productRepository.upsertProduct({
      ...productData,
      business_id: req.businessId,
    });

    // 2. Operational Mirror (Firestore/Firebase)
    if (req.services.firebase) {
      await req.services.firebase.upsert('products', productData.id, productData);
    }

    // 3. AI Analytical Mirroring (Non-blocking)
    try {
      await aiPipeline.processSyncEvent('products', operation || 'UPSERT', productData);
    } catch (err) {
      logger.error({ err }, 'Failed to mirror product to AI');
    }

    res.status(200).json({
      success: true,
      message: 'Product synchronized successfully',
      data: product,
      timestamp: new Date().toISOString(),
    });
  });

  getAll = asyncHandler(async (req, res) => {
    res.status(200).json({ success: true, data: [] });
  });
}

module.exports = new ProductController();
