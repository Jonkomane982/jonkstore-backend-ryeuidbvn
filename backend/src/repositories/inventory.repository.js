'use strict';

const { store: db } = require('../utils/db');
const { logger } = require('../utils/logger');

/**
 * Handles operational inventory management in JonkStore_Postgre.
 */
class InventoryRepository {
  /**
   * Retrieves current stock level for a product at a specific branch.
   */
  async getStockLevel(businessId, branchId, productId) {
    const query = `
      SELECT * FROM inventory
      WHERE business_id = $1 AND branch_id = $2 AND product_id = $3
    `;
    const res = await db.query(query, [businessId, branchId, productId]);
    return res.rows[0];
  }

  /**
   * Performs a manual stock adjustment.
   * Records the event in inventory_transactions for audit and AI analysis.
   */
  async adjustStock(data) {
    const client = await db.getClient();
    try {
      await client.query('BEGIN');

      // 1. Lock/Fetch current inventory
      const invRes = await client.query(
        'SELECT id, quantity FROM inventory WHERE business_id = $1 AND branch_id = $2 AND product_id = $3 FOR UPDATE',
        [data.business_id, data.branch_id, data.product_id]
      );

      if (invRes.rows.length === 0) {
        throw new Error('Inventory record not found for adjustment');
      }

      const inv = invRes.rows[0];
      const newQty = parseFloat(inv.quantity) + parseFloat(data.adjustment_qty);

      // 2. Update Quantity
      await client.query(
        'UPDATE inventory SET quantity = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2',
        [newQty, inv.id]
      );

      // 3. Log Transaction
      await client.query(`
        INSERT INTO inventory_transactions (
          business_id, branch_id, inventory_id, product_id,
          transaction_type, reference_id, reference_type,
          previous_quantity, quantity_change, resulting_quantity, user_id
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
      `, [
        data.business_id, data.branch_id, inv.id, data.product_id,
        'ADJUSTMENT', data.adjustment_id || inv.id, 'MANUAL_ADJUSTMENT',
        inv.quantity, data.adjustment_qty, newQty, data.user_id
      ]);

      await client.query('COMMIT');
      return { id: inv.id, newQuantity: newQty };
    } catch (err) {
      await client.query('ROLLBACK');
      logger.error({ err, data }, 'InventoryRepository: adjustStock failed');
      throw err;
    } finally {
      client.release();
    }
  }

  /**
   * Transfers stock between branches.
   */
  async transferStock(data) {
    const client = await db.getClient();
    try {
      await client.query('BEGIN');

      // 1. Deduct from Source
      const fromInvRes = await client.query(
        'SELECT id, quantity FROM inventory WHERE business_id = $1 AND branch_id = $2 AND product_id = $3 FOR UPDATE',
        [data.business_id, data.from_branch_id, data.product_id]
      );
      if (fromInvRes.rows[0].quantity < data.quantity) throw new Error('Insufficient stock for transfer');

      await client.query('UPDATE inventory SET quantity = quantity - $1 WHERE id = $2', [data.quantity, fromInvRes.rows[0].id]);

      // 2. Add to Destination
      await client.query(`
        INSERT INTO inventory (business_id, branch_id, product_id, quantity)
        VALUES ($1, $2, $3, $4)
        ON CONFLICT (branch_id, product_id)
        DO UPDATE SET quantity = inventory.quantity + EXCLUDED.quantity
      `, [data.business_id, data.to_branch_id, data.product_id, data.quantity]);

      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }
}

module.exports = new InventoryRepository();
