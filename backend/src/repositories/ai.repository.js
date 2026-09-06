'use strict';

const { ai: db } = require('../utils/db');
const { logger } = require('../utils/logger');

/**
 * Repository for JONK AI Data Foundation.
 * Interacts with the jonkai PostgreSQL database.
 */
class AIRepository {
  /**
   * Records a raw payload in the ingestion layer.
   * Enforces idempotency via the UNIQUE constraint on (source_system, source_record_id, source_version, event_type).
   */
  async ingestPayload(data) {
    const query = `
      INSERT INTO jonkai_ingest.payloads (
        source_system, source_record_id, source_version, business_id,
        event_type, payload, payload_hash, idempotency_key
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
      ON CONFLICT (source_system, source_record_id, source_version, event_type) DO NOTHING
      RETURNING id, status;
    `;
    const params = [
      data.sourceSystem,
      data.sourceRecordId,
      data.sourceVersion || 1,
      data.businessId,
      data.eventType,
      data.payload,
      data.payloadHash,
      data.idempotencyKey || null
    ];

    try {
      const res = await db.query(query, params);
      return res.rows[0] || null; // Returns null if record already existed (deduplicated)
    } catch (err) {
      logger.error({ err, data }, 'AI Repository: Payload ingestion failed');
      throw err;
    }
  }

  /**
   * Updates the status of an ingestion payload.
   */
  async updateIngestStatus(id, status, errorMessage = null) {
    const query = `
      UPDATE jonkai_ingest.payloads
      SET status = $2,
          error_message = $3,
          processed_at = CASE WHEN $2 = 'PROCESSED' THEN CURRENT_TIMESTAMP ELSE processed_at END,
          attempt_count = attempt_count + 1
      WHERE id = $1;
    `;
    return db.query(query, [id, status, errorMessage]);
  }

  /**
   * Logs a pipeline step for lineage.
   */
  async logPipelineStep(payloadId, businessId, stepName, status, details = null) {
    const query = `
      INSERT INTO jonkai_audit.pipeline_logs (payload_id, business_id, step_name, status, details)
      VALUES ($1, $2, $3, $4, $5);
    `;
    return db.query(query, [payloadId, businessId, stepName, status, details]);
  }

  /**
   * Mirrored Core: Upsert Business
   */
  async upsertCoreBusiness(business) {
    const query = `
      INSERT INTO jonkai_core.businesses (business_id, name, industry, source_version, payload)
      VALUES ($1, $2, $3, $4, $5)
      ON CONFLICT (business_id) DO UPDATE SET
        name = EXCLUDED.name,
        industry = EXCLUDED.industry,
        source_version = EXCLUDED.source_version,
        payload = EXCLUDED.payload,
        ingested_at = CURRENT_TIMESTAMP;
    `;
    return db.query(query, [
      business.id,
      business.name,
      business.industry || null,
      business.version || 1,
      business
    ]);
  }

  /**
   * Mirrored Core: Upsert Product
   */
  async upsertCoreProduct(product) {
    const query = `
      INSERT INTO jonkai_core.products (product_id, business_id, category_id, name, sku, selling_price, source_version, is_active)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
      ON CONFLICT (product_id) DO UPDATE SET
        name = EXCLUDED.name,
        category_id = EXCLUDED.category_id,
        sku = EXCLUDED.sku,
        selling_price = EXCLUDED.selling_price,
        source_version = EXCLUDED.source_version,
        is_active = EXCLUDED.is_active,
        ingested_at = CURRENT_TIMESTAMP;
    `;
    return db.query(query, [
      product.id,
      product.business_id,
      product.category_id || null,
      product.name,
      product.sku,
      product.selling_price,
      product.version || 1,
      product.is_active ?? true
    ]);
  }

  /**
   * Mirrored Core: Insert Sale and Items
   */
  async insertCoreSale(sale, items) {
    const client = await db.getClient();
    try {
      await client.query('BEGIN');

      const saleQuery = `
        INSERT INTO jonkai_core.sales (sale_id, business_id, branch_id, customer_id, employee_id, total_amount, sale_date, source_version, status)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
        ON CONFLICT (sale_id) DO NOTHING;
      `;
      await client.query(saleQuery, [
        sale.id,
        sale.business_id,
        sale.branch_id,
        sale.customer_id || null,
        sale.employee_id,
        sale.total_amount,
        sale.sale_date,
        sale.version || 1,
        sale.status
      ]);

      const itemQuery = `
        INSERT INTO jonkai_core.sale_items (sale_id, business_id, product_id, quantity, unit_price, unit_cost_at_sale)
        VALUES ($1, $2, $3, $4, $5, $6);
      `;

      for (const item of items) {
        await client.query(itemQuery, [
          sale.id,
          sale.business_id,
          item.product_id,
          item.quantity,
          item.unit_price,
          item.unit_cost_at_sale
        ]);
      }

      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK');
      logger.error({ err, saleId: sale.id }, 'AI Repository: Failed to mirror sale');
      throw err;
    } finally {
      client.release();
    }
  }

  /**
   * Analytical: Insert Fact Sale (Star Schema)
   */
  async insertFactSale(saleData) {
    const query = `
      INSERT INTO jonkai_analytics.fact_sales (
        business_id, branch_id, date_key, time_key,
        sale_timestamp, total_amount, cost_amount, source_sale_id
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
      ON CONFLICT (business_id, source_sale_id) DO NOTHING;
    `;
    // Note: date_key and time_key would be derived by the processor
    return db.query(query, [
      saleData.businessId,
      saleData.branchId,
      saleData.dateKey,
      saleData.timeKey,
      saleData.timestamp,
      saleData.totalAmount,
      saleData.costAmount,
      saleData.sourceSaleId
    ]);
  }
}

module.exports = new AIRepository();
