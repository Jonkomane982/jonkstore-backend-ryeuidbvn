'use strict';

const { store: db } = require('../utils/db');
const { logger } = require('../utils/logger');

/**
 * Handles the persistence of sales data in JonkStore_Postgre.
 * Ensures atomicity using transactions and hardened PostgreSQL procedures.
 */
class SaleRepository {
  /**
   * Creates a complete sale with items and payments, then finalizes stock.
   * Order of operations is critical: Sale -> Items -> Payments -> proc_complete_sale.
   * proc_complete_sale validates that payments cover the total_amount.
   */
  async createSale(saleData, items, payments = []) {
    const client = await db.getClient();
    try {
      await client.query('BEGIN');

      // 1. Insert the Sale record (status defaults to PENDING)
      const saleQuery = `
        INSERT INTO sales (
          id, business_id, branch_id, customer_id, employee_id,
          sale_number, receipt_number, total_amount, tax_total,
          discount_total, cost_total, status, source_id
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
        ON CONFLICT (id) DO UPDATE SET updated_at = CURRENT_TIMESTAMP
        RETURNING *;
      `;
      const saleRes = await client.query(saleQuery, [
        saleData.id,
        saleData.business_id,
        saleData.branch_id,
        saleData.customer_id || null,
        saleData.employee_id,
        saleData.sale_number,
        saleData.receipt_number,
        saleData.total_amount,
        saleData.tax_total || 0,
        saleData.discount_total || 0,
        saleData.cost_total || 0,
        'PENDING',
        saleData.source_id || null
      ]);

      // 2. Insert Sale Items
      const itemQuery = `
        INSERT INTO sale_items (
          id, business_id, sale_id, product_id, variant_id,
          quantity, unit_price, unit_cost_at_sale, total_price
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
        ON CONFLICT (id) DO NOTHING;
      `;

      for (const item of items) {
        await client.query(itemQuery, [
          item.id,
          saleData.business_id,
          saleData.id,
          item.product_id,
          item.variant_id || null,
          item.quantity,
          item.unit_price,
          item.unit_cost_at_sale,
          item.total_price
        ]);
      }

      // 3. Insert Payment Transactions (Required for procedure success)
      const paymentQuery = `
        INSERT INTO payment_transactions (
          id, business_id, sale_id, payment_method_id,
          amount, status, reference_number, source_id
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        ON CONFLICT (id) DO NOTHING;
      `;

      for (const pay of payments) {
        await client.query(paymentQuery, [
          pay.id,
          saleData.business_id,
          saleData.id,
          pay.payment_method_id,
          pay.amount,
          pay.status || 'CAPTURED',
          pay.reference_number || null,
          pay.source_id || null
        ]);
      }

      // 4. Execute the atomic completion procedure (Deducts stock & writes audit trail)
      // Procedure expects (sale_id, business_id, user_id)
      await client.query('CALL proc_complete_sale($1, $2, $3)', [
        saleData.id,
        saleData.business_id,
        saleData.employee_id
      ]);

      await client.query('COMMIT');
      return saleRes.rows[0];
    } catch (err) {
      await client.query('ROLLBACK');
      logger.error({ err, saleId: saleData.id }, 'SaleRepository: createSale failed');
      throw err;
    } finally {
      client.release();
    }
  }

  /**
   * Retrieves a sale by ID with customer and cashier names joined.
   */
  async findById(businessId, id) {
    const query = `
      SELECT s.*, c.name as customer_name, e.first_name || ' ' || e.last_name as cashier_name
      FROM sales s
      LEFT JOIN customers c ON s.customer_id = c.id
      JOIN employees e ON s.employee_id = e.id
      WHERE s.business_id = $1 AND s.id = $2
    `;
    const res = await db.query(query, [businessId, id]);
    return res.rows[0];
  }
}

module.exports = new SaleRepository();
