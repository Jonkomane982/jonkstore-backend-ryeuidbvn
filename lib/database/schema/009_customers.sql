-- 009_customers.sql
-- Customer Management, Addresses, Loyalty, and Transaction History

CREATE TABLE customers (
    id TEXT PRIMARY KEY,
    business_id TEXT NOT NULL,
    first_name TEXT NOT NULL,
    last_name TEXT,
    email TEXT,
    phone TEXT,
    tax_id TEXT, -- For corporate customers
    customer_type TEXT DEFAULT 'INDIVIDUAL', -- INDIVIDUAL, CORPORATE
    is_active INTEGER DEFAULT 1,
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
    FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE
);

CREATE TABLE customer_addresses (
    id TEXT PRIMARY KEY,
    customer_id TEXT NOT NULL,
    address_type TEXT DEFAULT 'SHIPPING', -- SHIPPING, BILLING
    address_line1 TEXT NOT NULL,
    address_line2 TEXT,
    city TEXT,
    state TEXT,
    country TEXT,
    postal_code TEXT,
    is_default INTEGER DEFAULT 0,
    -- Audit & Sync
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
    deleted_at TEXT,
    is_deleted INTEGER DEFAULT 0,
    sync_status TEXT DEFAULT 'PENDING',
    version INTEGER DEFAULT 1,
    created_by TEXT,
    updated_by TEXT,
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
);

CREATE TABLE customer_loyalty (
    id TEXT PRIMARY KEY,
    customer_id TEXT NOT NULL UNIQUE,
    points_balance REAL DEFAULT 0,
    tier TEXT DEFAULT 'BRONZE', -- BRONZE, SILVER, GOLD, PLATINUM
    total_spent REAL DEFAULT 0,
    last_purchase_date TEXT,
    -- Audit & Sync
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
    deleted_at TEXT,
    is_deleted INTEGER DEFAULT 0,
    sync_status TEXT DEFAULT 'PENDING',
    version INTEGER DEFAULT 1,
    created_by TEXT,
    updated_by TEXT,
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
);

CREATE TABLE customer_transactions (
    id TEXT PRIMARY KEY,
    customer_id TEXT NOT NULL,
    transaction_type TEXT NOT NULL, -- SALE, RETURN, PAYMENT, ADJUSTMENT
    reference_id TEXT, -- Sale ID or Payment ID
    amount REAL NOT NULL,
    balance_after REAL NOT NULL,
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
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
);
