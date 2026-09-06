'use strict';

const { store: db } = require('../utils/db');
const { logger } = require('../utils/logger');

/**
 * Handles operational procurement in JonkStore_Postgre.
 */
class PurchaseRepository {
  async createOrder(data, items) {
    const client = await db.getClient();
    try {
      await client.query('BEGIN');

      const poQuery = `
        INSERT INTO purchase_orders (
          id, business_id, branch_id, supplier_id, order_number,
          subtotal, tax_total, total_amount, status, source_id
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
        RETURNING *;
      `;
      const poRes = await client.query(poQuery, [
        data.id, data.business_id, data.branch_id, data.supplier_id, data.order_number,
        data.subtotal, data.tax_total, data.total_amount, 'PENDING', data.source_id
      ]);

      const itemQuery = `
        INSERT INTO purchase_order_items (
          business_id, purchase_order_id, product_id, quantity,
          unit_buying_price, landed_unit_cost, total_buying_price
        ) VALUES ($1, $2, $3, $4, $5, $6, $7);
      `;

      for (const item of items) {
        await client.query(itemQuery, [
          data.business_id, data.id, item.product_id, item.quantity,
          item.unit_buying_price, item.landed_unit_cost, item.total_buying_price
        ]);
      }

      await client.query('COMMIT');
      return poRes.rows[0];
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  /**
   * Records receipt of goods and triggers the atomic WAC calculation.
   */
  async receivePurchase(poId, businessId, receivedItems, userId) {
    const query = 'CALL proc_receive_purchase($1, $2, $3, $4)';
    return db.query(query, [poId, businessId, JSON.stringify(receivedItems), userId]);
  }
}

module.exports = new PurchaseRepository();
