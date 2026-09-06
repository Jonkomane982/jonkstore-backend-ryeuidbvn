-- 008_inventory.sql
-- Inventory Management, Transactions, Adjustments, and Stock Control

CREATE TABLE inventory (
    id TEXT PRIMARY KEY,
    product_id TEXT NOT NULL,
    variant_id TEXT,
    branch_id TEXT NOT NULL,
    quantity REAL NOT NULL DEFAULT 0,
    reserved_quantity REAL DEFAULT 0, -- Stock committed to pending sales/orders
    low_stock_threshold REAL,
    reorder_level REAL,
    bin_location TEXT, -- Warehouse location
    last_count_date TEXT,
    -- Audit & Sync
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
    deleted_at TEXT,
    is_deleted INTEGER DEFAULT 0,
    sync_status TEXT DEFAULT 'PENDING',
    version INTEGER DEFAULT 1,
    created_by TEXT,
    updated_by TEXT,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    FOREIGN KEY (variant_id) REFERENCES product_variants(id) ON DELETE CASCADE,
    FOREIGN KEY (branch_id) REFERENCES branches(id) ON DELETE CASCADE,
    UNIQUE(product_id, variant_id, branch_id)
);

CREATE TABLE inventory_transactions (
    id TEXT PRIMARY KEY,
    inventory_id TEXT NOT NULL,
    transaction_type TEXT NOT NULL, -- PURCHASE, SALE, ADJUSTMENT, TRANSFER_IN, TRANSFER_OUT, RETURN
    reference_id TEXT, -- ID of the Sale, PurchaseOrder, or Adjustment
    quantity_change REAL NOT NULL,
    previous_quantity REAL NOT NULL,
    new_quantity REAL NOT NULL,
    reason TEXT,
    transaction_date TEXT DEFAULT CURRENT_TIMESTAMP,
    -- Audit & Sync
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
    deleted_at TEXT,
    is_deleted INTEGER DEFAULT 0,
    sync_status TEXT DEFAULT 'PENDING',
    version INTEGER DEFAULT 1,
    created_by TEXT,
    updated_by TEXT,
    FOREIGN KEY (inventory_id) REFERENCES inventory(id) ON DELETE CASCADE
);

CREATE TABLE inventory_adjustments (
    id TEXT PRIMARY KEY,
    branch_id TEXT NOT NULL,
    adjustment_date TEXT DEFAULT CURRENT_TIMESTAMP,
    reason_code TEXT NOT NULL, -- DAMAGE, LOSS, CORRECTION, THEFT
    notes TEXT,
    status TEXT DEFAULT 'COMPLETED', -- PENDING, COMPLETED, CANCELLED
    -- Audit & Sync
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
    deleted_at TEXT,
    is_deleted INTEGER DEFAULT 0,
    sync_status TEXT DEFAULT 'PENDING',
    version INTEGER DEFAULT 1,
    created_by TEXT,
    updated_by TEXT,
    FOREIGN KEY (branch_id) REFERENCES branches(id) ON DELETE CASCADE
);

CREATE TABLE inventory_counts (
    id TEXT PRIMARY KEY,
    branch_id TEXT NOT NULL,
    count_date TEXT DEFAULT CURRENT_TIMESTAMP,
    status TEXT DEFAULT 'IN_PROGRESS', -- IN_PROGRESS, RECONCILED, CLOSED
    notes TEXT,
    -- Audit & Sync
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
    deleted_at TEXT,
    is_deleted INTEGER DEFAULT 0,
    sync_status TEXT DEFAULT 'PENDING',
    version INTEGER DEFAULT 1,
    created_by TEXT,
    updated_by TEXT,
    FOREIGN KEY (branch_id) REFERENCES branches(id) ON DELETE CASCADE
);

CREATE TABLE stock_transfers (
    id TEXT PRIMARY KEY,
    from_branch_id TEXT NOT NULL,
    to_branch_id TEXT NOT NULL,
    transfer_date TEXT DEFAULT CURRENT_TIMESTAMP,
    status TEXT DEFAULT 'PENDING', -- PENDING, SHIPPED, RECEIVED, CANCELLED
    tracking_number TEXT,
    notes TEXT,
    -- Audit & Sync
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
    deleted_at TEXT,
    is_deleted INTEGER DEFAULT 0,
    sync_status TEXT DEFAULT 'PENDING',
    version INTEGER DEFAULT 1,
    created_by TEXT,
    updated_by TEXT,
    FOREIGN KEY (from_branch_id) REFERENCES branches(id),
    FOREIGN KEY (to_branch_id) REFERENCES branches(id)
);

CREATE TABLE stock_alerts (
    id TEXT PRIMARY KEY,
    inventory_id TEXT NOT NULL,
    alert_type TEXT NOT NULL, -- LOW_STOCK, OUT_OF_STOCK, EXPIRING_SOON
    severity TEXT DEFAULT 'MEDIUM', -- LOW, MEDIUM, HIGH, CRITICAL
    message TEXT,
    is_resolved INTEGER DEFAULT 0,
    resolved_at TEXT,
    -- Audit & Sync
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
    deleted_at TEXT,
    is_deleted INTEGER DEFAULT 0,
    sync_status TEXT DEFAULT 'PENDING',
    version INTEGER DEFAULT 1,
    created_by TEXT,
    updated_by TEXT,
    FOREIGN KEY (inventory_id) REFERENCES inventory(id) ON DELETE CASCADE
);
