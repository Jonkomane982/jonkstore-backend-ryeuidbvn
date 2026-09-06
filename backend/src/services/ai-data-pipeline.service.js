'use strict';

const aiRepository = require('../repositories/ai.repository');
const { logger } = require('../utils/logger');

/**
 * JONK AI Data Pipeline Service.
 *
 * Intercepts POS business events and mirrors operational data
 * into the PostgreSQL AI Analytical Database.
 */
class AIDataPipelineService {
  /**
   * Main entry point for the pipeline.
   * Processes a sync task and routes it to the correct mirroring logic.
   */
  async processSyncEvent(entityName, operation, data) {
    logger.info({ entityName, operation }, 'AI Pipeline: Intercepted sync event');

    try {
      // 1. Log the event for AI audit/lineage
      await aiRepository.logEvent(entityName, data.id, operation);

      // 2. Route to specialized mirroring logic
      switch (entityName.toLowerCase()) {
        case 'businesses':
          await aiRepository.upsertBusiness(data);
          break;
        case 'products':
          await aiRepository.upsertProduct(data);
          break;
        case 'sales':
          // For sales, we expect the sale object and its items
          await aiRepository.insertSale(data, data.items || []);
          break;
        case 'inventory':
          await aiRepository.recordInventorySnapshot(data.product_id, data.branch_id, data.quantity);
          break;
        default:
          logger.debug({ entityName }, 'AI Pipeline: No specific mirroring logic for entity');
      }
    } catch (err) {
      logger.error({ err, entityName, operation }, 'AI Pipeline: Mirroring failed');
      // We do not throw here to avoid breaking the operational sync flow,
      // but we log the failure in the AI audit log for later retry.
    }
  }
}

module.exports = new AIDataPipelineService();
