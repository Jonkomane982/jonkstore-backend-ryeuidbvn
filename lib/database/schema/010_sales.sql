-- 010_sales.sql
-- Sales Management, Items, Discounts, Taxes, and Returns

CREATE TABLE sales (
    id TEXT PRIMARY KEY,
    business_id TEXT NOT NULL,
    branch_id TEXT NOT NULL,
    customer_id TEXT, -- Null for guest checkout
    employee_id TEXT NOT NULL, -- Who performed the sale
    invoice_number TEXT UNIQUE, -- e.g., INV-2024-0001
    sale_date TEXT DEFAULT CURRENT_TIMESTAMP,
    status TEXT NOT NULL DEFAULT 'COMPLETED', -- COMPLETED, ON_HOLD, CANCELLED, REFUNDED
    subtotal REAL NOT NULL DEFAULT 0,
    discount_total REAL NOT NULL DEFAULT 0,
    tax_total REAL NOT NULL DEFAULT 0,
    total_amount REAL NOT NULL DEFAULT 0,
    paid_amount REAL NOT NULL DEFAULT 0,
    change_amount REAL NOT NULL DEFAULT 0,
    payment_status TEXT NOT NULL DEFAULT 'PAID', -- PAID, PARTIAL, UNPAID
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
    FOREIGN KEY (customer_id) REFERENCES customers(id),
    FOREIGN KEY (employee_id) REFERENCES employees(id)
);

CREATE TABLE sale_items (
    id TEXT PRIMARY KEY,
    sale_id TEXT NOT NULL,
    product_id TEXT NOT NULL,
    variant_id TEXT,
    sku TEXT,
    name TEXT NOT NULL, -- Snapshot of name at time of sale
    quantity REAL NOT NULL,
    unit_price REAL NOT NULL,
    cost_price REAL NOT NULL, -- For profit calculations
    tax_rate REAL DEFAULT 0,
    tax_amount REAL DEFAULT 0,
    discount_rate REAL DEFAULT 0,
    discount_amount REAL DEFAULT 0,
    total_amount REAL NOT NULL,
    is_returned INTEGER DEFAULT 0,
    return_quantity REAL DEFAULT 0,
    -- Audit & Sync
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
    deleted_at TEXT,
    is_deleted INTEGER DEFAULT 0,
    sync_status TEXT DEFAULT 'PENDING',
    version INTEGER DEFAULT 1,
    created_by TEXT,
    updated_by TEXT,
    FOREIGN KEY (sale_id) REFERENCES sales(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id),
    FOREIGN KEY (variant_id) REFERENCES product_variants(id),
    CHECK (quantity > 0)
);

CREATE TABLE sale_discounts (
    id TEXT PRIMARY KEY,
    sale_id TEXT NOT NULL,
    name TEXT NOT NULL, -- e.g., Seasonal Discount, Coupon
    type TEXT NOT NULL, -- PERCENTAGE, FIXED_AMOUNT
    value REAL NOT NULL,
    amount REAL NOT NULL,
    -- Audit & Sync
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
    deleted_at TEXT,
    is_deleted INTEGER DEFAULT 0,
    sync_status TEXT DEFAULT 'PENDING',
    version INTEGER DEFAULT 1,
    created_by TEXT,
    updated_by TEXT,
    FOREIGN KEY (sale_id) REFERENCES sales(id) ON DELETE CASCADE
);

CREATE TABLE sale_taxes (
    id TEXT PRIMARY KEY,
    sale_id TEXT NOT NULL,
    tax_id TEXT NOT NULL,
    name TEXT NOT NULL,
    rate REAL NOT NULL,
    amount REAL NOT NULL,
    -- Audit & Sync
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
    deleted_at TEXT,
    is_deleted INTEGER DEFAULT 0,
    sync_status TEXT DEFAULT 'PENDING',
    version INTEGER DEFAULT 1,
    created_by TEXT,
    updated_by TEXT,
    FOREIGN KEY (sale_id) REFERENCES sales(id) ON DELETE CASCADE,
    FOREIGN KEY (tax_id) REFERENCES taxes(id)
);

CREATE TABLE sale_returns (
    id TEXT PRIMARY KEY,
    sale_id TEXT NOT NULL,
    branch_id TEXT NOT NULL,
    employee_id TEXT NOT NULL,
    return_date TEXT DEFAULT CURRENT_TIMESTAMP,
    reason TEXT,
    total_refund_amount REAL NOT NULL,
    refund_method TEXT NOT NULL, -- CASH, CREDIT_NOTE, ORIGINAL_METHOD
    -- Audit & Sync
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
    deleted_at TEXT,
    is_deleted INTEGER DEFAULT 0,
    sync_status TEXT DEFAULT 'PENDING',
    version INTEGER DEFAULT 1,
    created_by TEXT,
    updated_by TEXT,
    FOREIGN KEY (sale_id) REFERENCES sales(id) ON DELETE CASCADE,
    FOREIGN KEY (branch_id) REFERENCES branches(id),
    FOREIGN KEY (employee_id) REFERENCES employees(id)
);
