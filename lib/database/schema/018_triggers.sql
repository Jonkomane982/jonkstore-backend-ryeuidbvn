-- 018_triggers.sql
-- Production Grade Triggers for Data Integrity, Auditing, and Automation

-- 1. AUTOMATIC UPDATED_AT UPDATES
-- We create these for major tables to ensure the timestamp is always current.

CREATE TRIGGER trg_businesses_updated_at AFTER UPDATE ON businesses
BEGIN
    UPDATE businesses SET updated_at = CURRENT_TIMESTAMP, sync_status = 'PENDING', version = version + 1 WHERE id = OLD.id;
END;

CREATE TRIGGER trg_branches_updated_at AFTER UPDATE ON branches
BEGIN
    UPDATE branches SET updated_at = CURRENT_TIMESTAMP, sync_status = 'PENDING', version = version + 1 WHERE id = OLD.id;
END;

CREATE TRIGGER trg_employees_updated_at AFTER UPDATE ON employees
BEGIN
    UPDATE employees SET updated_at = CURRENT_TIMESTAMP, sync_status = 'PENDING', version = version + 1 WHERE id = OLD.id;
END;

CREATE TRIGGER trg_products_updated_at AFTER UPDATE ON products
BEGIN
    UPDATE products SET updated_at = CURRENT_TIMESTAMP, sync_status = 'PENDING', version = version + 1 WHERE id = OLD.id;
END;

CREATE TRIGGER trg_product_variants_updated_at AFTER UPDATE ON product_variants
BEGIN
    UPDATE product_variants SET updated_at = CURRENT_TIMESTAMP, sync_status = 'PENDING', version = version + 1 WHERE id = OLD.id;
END;

CREATE TRIGGER trg_inventory_updated_at AFTER UPDATE ON inventory
BEGIN
    UPDATE inventory SET updated_at = CURRENT_TIMESTAMP, sync_status = 'PENDING', version = version + 1 WHERE id = OLD.id;
END;

CREATE TRIGGER trg_customers_updated_at AFTER UPDATE ON customers
BEGIN
    UPDATE customers SET updated_at = CURRENT_TIMESTAMP, sync_status = 'PENDING', version = version + 1 WHERE id = OLD.id;
END;

CREATE TRIGGER trg_suppliers_updated_at AFTER UPDATE ON suppliers
BEGIN
    UPDATE suppliers SET updated_at = CURRENT_TIMESTAMP, sync_status = 'PENDING', version = version + 1 WHERE id = OLD.id;
END;


-- 2. PREVENT NEGATIVE STOCK
-- Critical for POS systems to maintain data integrity.

CREATE TRIGGER trg_prevent_negative_stock
BEFORE UPDATE ON inventory
WHEN NEW.quantity < 0
BEGIN
    SELECT RAISE(ABORT, 'Operation failed: Stock cannot be negative.');
END;


-- 3. AUTOMATIC INVENTORY UPDATES FROM SALES
-- When a sale item is added, decrease the inventory quantity.

CREATE TRIGGER trg_sale_item_inventory_decrement
AFTER INSERT ON sale_items
BEGIN
    -- Decrease stock
    UPDATE inventory
    SET quantity = quantity - NEW.quantity,
        updated_at = CURRENT_TIMESTAMP
    WHERE product_id = NEW.product_id
      AND (variant_id = NEW.variant_id OR (variant_id IS NULL AND NEW.variant_id IS NULL));

    -- Log transaction
    INSERT INTO inventory_transactions (
        id, inventory_id, transaction_type, reference_id,
        quantity_change, previous_quantity, new_quantity, reason
    )
    SELECT
        lower(hex(randomblob(16))), i.id, 'SALE', NEW.sale_id,
        -NEW.quantity, i.quantity + NEW.quantity, i.quantity, 'Sale processed'
    FROM inventory i
    WHERE i.product_id = NEW.product_id
      AND (i.variant_id = NEW.variant_id OR (i.variant_id IS NULL AND NEW.variant_id IS NULL));
END;


-- 4. AUTOMATIC INVENTORY UPDATES FROM PURCHASES
-- When received_quantity in purchase_order_items is updated, increase inventory.

CREATE TRIGGER trg_purchase_item_inventory_increment
AFTER UPDATE OF received_quantity ON purchase_order_items
WHEN NEW.received_quantity > OLD.received_quantity
BEGIN
    -- Increase stock by the difference
    UPDATE inventory
    SET quantity = quantity + (NEW.received_quantity - OLD.received_quantity),
        updated_at = CURRENT_TIMESTAMP
    WHERE product_id = NEW.product_id
      AND (variant_id = NEW.variant_id OR (variant_id IS NULL AND NEW.variant_id IS NULL));

    -- Log transaction
    INSERT INTO inventory_transactions (
        id, inventory_id, transaction_type, reference_id,
        quantity_change, previous_quantity, new_quantity, reason
    )
    SELECT
        lower(hex(randomblob(16))), i.id, 'PURCHASE', NEW.purchase_order_id,
        (NEW.received_quantity - OLD.received_quantity),
        i.quantity - (NEW.received_quantity - OLD.received_quantity),
        i.quantity, 'Purchase received'
    FROM inventory i
    WHERE i.product_id = NEW.product_id
      AND (i.variant_id = NEW.variant_id OR (i.variant_id IS NULL AND NEW.variant_id IS NULL));
END;


-- 5. AUTOMATIC AUDIT LOGGING (Example for Products)
-- Tracks changes for sensitive data.

CREATE TRIGGER trg_audit_products_update
AFTER UPDATE ON products
BEGIN
    INSERT INTO audit_logs (
        id, table_name, record_id, action, old_values, new_values, employee_id
    )
    VALUES (
        lower(hex(randomblob(16))),
        'products',
        OLD.id,
        'UPDATE',
        json_object('name', OLD.name, 'sku', OLD.sku, 'is_active', OLD.is_active),
        json_object('name', NEW.name, 'sku', NEW.sku, 'is_active', NEW.is_active),
        NEW.updated_by
    );
END;


-- 6. SYNC STATUS AUTOMATION
-- Ensures any local change is flagged for server synchronization.

CREATE TRIGGER trg_flag_sync_on_insert
AFTER INSERT ON sales
BEGIN
    INSERT INTO sync_queue (id, table_name, record_id, operation)
    VALUES (lower(hex(randomblob(16))), 'sales', NEW.id, 'INSERT');
END;


-- 7. STOCK ALERT TRIGGER
-- Automatically create an alert when inventory falls below threshold.

CREATE TRIGGER trg_inventory_low_stock_alert
AFTER UPDATE OF quantity ON inventory
WHEN NEW.quantity <= NEW.low_stock_threshold AND OLD.quantity > NEW.low_stock_threshold
BEGIN
    INSERT INTO stock_alerts (
        id, inventory_id, alert_type, severity, message
    )
    VALUES (
        lower(hex(randomblob(16))),
        NEW.id,
        'LOW_STOCK',
        'HIGH',
        'Stock level dropped to ' || NEW.quantity || '. Threshold is ' || NEW.low_stock_threshold
    );

    -- Also create a system notification
    INSERT INTO notifications (
        id, business_id, branch_id, title, message, type, priority
    )
    SELECT
        lower(hex(randomblob(16))), b.business_id, NEW.branch_id,
        'Low Stock Alert',
        'Product stock is low at ' || b.name,
        'WARNING', 'HIGH'
    FROM branches b WHERE b.id = NEW.branch_id;
END;
