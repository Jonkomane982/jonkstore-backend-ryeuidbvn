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
   * Ensures WAC is preserved and movement is logged for AI analysis.
   */
  async transferStock(data) {
    const client = await db.getClient();
    try {
      await client.query('BEGIN');

      // 1. Lock and Fetch Source Inventory
      const fromInvRes = await client.query(
        'SELECT id, quantity, weighted_average_cost FROM inventory WHERE business_id = $1 AND branch_id = $2 AND product_id = $3 FOR UPDATE',
        [data.business_id, data.from_branch_id, data.product_id]
      );

      if (fromInvRes.rows.length === 0 || fromInvRes.rows[0].quantity < data.quantity) {
        throw new Error('Insufficient stock or product not found at source branch');
      }

      const fromInv = fromInvRes.rows[0];
      const sourceWac = fromInv.weighted_average_cost;

      // 2. Deduct from Source
      await client.query('UPDATE inventory SET quantity = quantity - $1 WHERE id = $2', [data.quantity, fromInv.id]);

      // 3. Log TRANSFER_OUT
      await client.query(`
        INSERT INTO inventory_transactions (
          business_id, branch_id, inventory_id, product_id, transaction_type,
          reference_id, reference_type, previous_quantity, quantity_change,
          resulting_quantity, unit_cost, user_id
        ) VALUES ($1, $2, $3, $4, 'TRANSFER_OUT', $5, 'BRANCH_TRANSFER', $6, $7, $8, $9, $10)
      `, [
        data.business_id, data.from_branch_id, fromInv.id, data.product_id,
        data.transfer_id || fromInv.id, fromInv.quantity, -data.quantity,
        fromInv.quantity - data.quantity, sourceWac, data.user_id
      ]);

      // 4. Lock/Fetch/Create Destination Inventory
      await client.query(`
        INSERT INTO inventory (business_id, branch_id, product_id, quantity, weighted_average_cost)
        VALUES ($1, $2, $3, 0, $4)
        ON CONFLICT (branch_id, product_id) DO NOTHING
      `, [data.business_id, data.to_branch_id, data.product_id, sourceWac]);

      const toInvRes = await client.query(
        'SELECT id, quantity, weighted_average_cost FROM inventory WHERE business_id = $1 AND branch_id = $2 AND product_id = $3 FOR UPDATE',
        [data.business_id, data.to_branch_id, data.product_id]
      );
      const toInv = toInvRes.rows[0];

      // 5. Update Destination (WAC Recalculation)
      const newToQty = parseFloat(toInv.quantity) + parseFloat(data.quantity);
      // If we move stock at cost, we blend it into the destination WAC
      const newToWac = ((parseFloat(toInv.quantity) * parseFloat(toInv.weighted_average_cost)) + (parseFloat(data.quantity) * parseFloat(sourceWac))) / newToQty;

      await client.query(
        'UPDATE inventory SET quantity = $1, weighted_average_cost = $2, updated_at = CURRENT_TIMESTAMP WHERE id = $3',
        [newToQty, newToWac, toInv.id]
      );

      // 6. Log TRANSFER_IN
      await client.query(`
        INSERT INTO inventory_transactions (
          business_id, branch_id, inventory_id, product_id, transaction_type,
          reference_id, reference_type, previous_quantity, quantity_change,
          resulting_quantity, unit_cost, user_id
        ) VALUES ($1, $2, $3, $4, 'TRANSFER_IN', $5, 'BRANCH_TRANSFER', $6, $7, $8, $9, $10)
      `, [
        data.business_id, data.to_branch_id, toInv.id, data.product_id,
        data.transfer_id || toInv.id, toInv.quantity, data.quantity,
        newToQty, sourceWac, data.user_id
      ]);

      await client.query('COMMIT');
      return { status: 'success' };
    } catch (err) {
      await client.query('ROLLBACK');
      logger.error({ err, data }, 'InventoryRepository: transferStock failed');
      throw err;
    } finally {
      client.release();
    }
  }
}

module.exports = new InventoryRepository();
