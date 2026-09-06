-- 002_business.sql
-- Business and Branch Management

CREATE TABLE currencies (
    id TEXT PRIMARY KEY,
    code TEXT NOT NULL UNIQUE, -- e.g., KES, USD
    name TEXT NOT NULL,
    symbol TEXT NOT NULL,
    exchange_rate REAL DEFAULT 1.0,
    is_active INTEGER DEFAULT 1,
    -- Audit & Sync
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
    deleted_at TEXT,
    is_deleted INTEGER DEFAULT 0,
    sync_status TEXT DEFAULT 'PENDING',
    version INTEGER DEFAULT 1,
    created_by TEXT,
    updated_by TEXT
);

CREATE TABLE businesses (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    tax_id TEXT,
    registration_number TEXT,
    email TEXT,
    phone TEXT,
    website TEXT,
    logo_url TEXT,
    currency_id TEXT NOT NULL,
    base_timezone TEXT DEFAULT 'UTC',
    is_active INTEGER DEFAULT 1,
    -- Audit & Sync
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
    deleted_at TEXT,
    is_deleted INTEGER DEFAULT 0,
    sync_status TEXT DEFAULT 'PENDING',
    version INTEGER DEFAULT 1,
    created_by TEXT,
    updated_by TEXT,
    FOREIGN KEY (currency_id) REFERENCES currencies(id)
);

CREATE TABLE branches (
    id TEXT PRIMARY KEY,
    business_id TEXT NOT NULL,
    name TEXT NOT NULL,
    code TEXT UNIQUE, -- e.g., BR001
    address TEXT,
    city TEXT,
    state TEXT,
    country TEXT,
    postal_code TEXT,
    phone TEXT,
    email TEXT,
    is_main_branch INTEGER DEFAULT 0,
    is_active INTEGER DEFAULT 1,
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

CREATE TABLE business_settings (
    id TEXT PRIMARY KEY,
    business_id TEXT NOT NULL,
    setting_key TEXT NOT NULL,
    setting_value TEXT,
    description TEXT,
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
    UNIQUE(business_id, setting_key)
);

CREATE TABLE receipt_settings (
    id TEXT PRIMARY KEY,
    branch_id TEXT NOT NULL,
    header_text TEXT,
    footer_text TEXT,
    show_logo INTEGER DEFAULT 1,
    show_tax_details INTEGER DEFAULT 1,
    show_customer_details INTEGER DEFAULT 1,
    paper_size TEXT DEFAULT '80mm', -- e.g., 58mm, 80mm, A4
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

CREATE TABLE taxes (
    id TEXT PRIMARY KEY,
    business_id TEXT NOT NULL,
    name TEXT NOT NULL, -- e.g., VAT, Sales Tax
    rate REAL NOT NULL, -- Percentage
    is_compound INTEGER DEFAULT 0,
    is_active INTEGER DEFAULT 1,
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
    CHECK (rate >= 0)
);
