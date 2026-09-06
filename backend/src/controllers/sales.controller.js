'use strict';

const { asyncHandler } = require('../utils/helpers');
const aiPipeline = require('../services/ai-data-pipeline.service');
const saleRepository = require('../repositories/sale.repository');
const { logger } = require('../utils/logger');

/**
 * Handles Sales synchronization and operational logic.
 */
class SalesController {
  /**
   * Syncs a sale from the POS to PostgreSQL, Firebase, and JonkAI.
   */
  syncSale = asyncHandler(async (req, res) => {
    const saleData = req.body;
    const { operation } = req.query;

    logger.info({ saleId: saleData.id, operation }, 'Syncing sale');

    // 1. Operational Persistence (PostgreSQL - The source of truth)
    // Uses the hardened transaction + procedure flow
    const sale = await saleRepository.createSale({
      ...saleData,
      business_id: req.businessId,
    }, saleData.items || []);

    // 2. Operational Mirror (Firestore/Firebase)
    if (req.services.firebase) {
      await req.services.firebase.upsert('sales', saleData.id, saleData);
    }

    // 3. AI Analytical Mirroring (Non-blocking)
    try {
      await aiPipeline.processSyncEvent('sales', operation || 'CREATE', saleData);
    } catch (err) {
      logger.error({ err }, 'Failed to mirror sale to AI');
    }

    res.status(200).json({
      success: true,
      message: 'Sale synchronized successfully',
      data: sale,
      timestamp: new Date().toISOString(),
    });
  });

  getById = asyncHandler(async (req, res) => {
    res.status(200).json({ success: true, data: {} });
  });
}

module.exports = new SalesController();
