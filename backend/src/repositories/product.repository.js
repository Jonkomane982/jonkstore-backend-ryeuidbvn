'use strict';

const { store: db } = require('../utils/db');

class ProductRepository {
  async findBySku(businessId, sku) {
    const query = 'SELECT * FROM products WHERE business_id = $1 AND sku = $2 AND is_deleted = FALSE';
    const res = await db.query(query, [businessId, sku]);
    return res.rows[0];
  }

  async upsertProduct(data) {
    const query = `
      INSERT INTO products (
        id, business_id, category_id, brand_id, unit_id,
        name, sku, description, selling_price, track_inventory
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
      ON CONFLICT (id) DO UPDATE SET
        category_id = EXCLUDED.category_id,
        name = EXCLUDED.name,
        description = EXCLUDED.description,
        selling_price = EXCLUDED.selling_price,
        updated_at = CURRENT_TIMESTAMP,
        version = products.version + 1
      RETURNING *;
    `;
    const params = [
      data.id, data.business_id, data.category_id, data.brand_id, data.unit_id,
      data.name, data.sku, data.description, data.selling_price, data.track_inventory
    ];
    const res = await db.query(query, params);
    return res.rows[0];
  }

  async getInventory(businessId, branchId, productId) {
    const query = 'SELECT * FROM inventory WHERE business_id = $1 AND branch_id = $2 AND product_id = $3';
    const res = await db.query(query, [businessId, branchId, productId]);
    return res.rows[0];
  }
}

module.exports = new ProductRepository();
