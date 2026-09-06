-- 007_purchases.sql
-- Purchase Orders, Items, Payments, and Runner Fee Management

CREATE TABLE purchase_orders (
    id TEXT PRIMARY KEY,
    business_id TEXT NOT NULL,
    branch_id TEXT NOT NULL,
    supplier_id TEXT NOT NULL,
    order_number TEXT UNIQUE, -- e.g., PO-2024-001
    order_date TEXT DEFAULT CURRENT_TIMESTAMP,
    expected_delivery_date TEXT,
    received_date TEXT,
    status TEXT NOT NULL DEFAULT 'DRAFT', -- DRAFT, SENT, PARTIAL, RECEIVED, CANCELLED
    payment_status TEXT NOT NULL DEFAULT 'UNPAID', -- UNPAID, PARTIAL, PAID
    subtotal REAL DEFAULT 0,
    tax_total REAL DEFAULT 0,
    shipping_cost REAL DEFAULT 0,
    other_costs REAL DEFAULT 0, -- Used for Runner Fee
    allocation_method TEXT DEFAULT 'PROPORTIONAL', -- PROPORTIONAL, EQUAL
    total_amount REAL DEFAULT 0, -- Total Investment
    paid_amount REAL DEFAULT 0,
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
    FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE,
    FOREIGN KEY (branch_id) REFERENCES branches(id) ON DELETE CASCADE,
    FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
);

CREATE TABLE purchase_order_items (
    id TEXT PRIMARY KEY,
    purchase_order_id TEXT NOT NULL,
    product_id TEXT NOT NULL,
    variant_id TEXT,
    sku TEXT,
    quantity REAL NOT NULL,
    received_quantity REAL DEFAULT 0,
    unit_cost REAL NOT NULL,
    tax_rate REAL DEFAULT 0,
    tax_amount REAL DEFAULT 0,
    discount_rate REAL DEFAULT 0,
    discount_amount REAL DEFAULT 0,
    total_cost REAL NOT NULL,
    expiry_date TEXT,
    batch_number TEXT,
    -- Audit & Sync
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
    deleted_at TEXT,
    is_deleted INTEGER DEFAULT 0,
    sync_status TEXT DEFAULT 'PENDING',
    version INTEGER DEFAULT 1,
    created_by TEXT,
    updated_by TEXT,
    FOREIGN KEY (purchase_order_id) REFERENCES purchase_orders(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id),
    FOREIGN KEY (variant_id) REFERENCES product_variants(id),
    CHECK (quantity > 0)
);

CREATE TABLE purchase_payments (
    id TEXT PRIMARY KEY,
    purchase_order_id TEXT NOT NULL,
    payment_date TEXT DEFAULT CURRENT_TIMESTAMP,
    payment_method_id TEXT, -- References payment_methods table
    amount REAL NOT NULL,
    reference_number TEXT,
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
    FOREIGN KEY (purchase_order_id) REFERENCES purchase_orders(id) ON DELETE CASCADE
);

CREATE TABLE runner_fees (
    id TEXT PRIMARY KEY,
    purchase_order_id TEXT NOT NULL,
    runner_name TEXT,
    amount REAL NOT NULL,
    payment_date TEXT DEFAULT CURRENT_TIMESTAMP,
    payment_status TEXT DEFAULT 'PENDING', -- PENDING, PAID
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
    FOREIGN KEY (purchase_order_id) REFERENCES purchase_orders(id) ON DELETE CASCADE
);

CREATE TABLE runner_fee_allocations (
    id TEXT PRIMARY KEY,
    runner_fee_id TEXT NOT NULL,
    purchase_order_item_id TEXT NOT NULL,
    allocated_amount REAL NOT NULL,
    -- Audit & Sync
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
    deleted_at TEXT,
    is_deleted INTEGER DEFAULT 0,
    sync_status TEXT DEFAULT 'PENDING',
    version INTEGER DEFAULT 1,
    created_by TEXT,
    updated_by TEXT,
    FOREIGN KEY (runner_fee_id) REFERENCES runner_fees(id) ON DELETE CASCADE,
    FOREIGN KEY (purchase_order_item_id) REFERENCES purchase_order_items(id) ON DELETE CASCADE
);
