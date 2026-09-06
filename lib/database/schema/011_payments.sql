-- 011_payments.sql
-- Payment Methods, Transactions, and Reconciliation Management

CREATE TABLE payment_methods (
    id TEXT PRIMARY KEY,
    business_id TEXT NOT NULL,
    name TEXT NOT NULL, -- e.g., Cash, M-Pesa, Card, Bank Transfer
    type TEXT NOT NULL, -- CASH, MOBILE_MONEY, CARD, BANK
    provider_name TEXT, -- e.g., Safaricom, KCB
    is_active INTEGER DEFAULT 1,
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
    FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE
);

CREATE TABLE sale_payments (
    id TEXT PRIMARY KEY,
    sale_id TEXT NOT NULL,
    payment_method_id TEXT NOT NULL,
    amount REAL NOT NULL,
    transaction_reference TEXT, -- e.g., M-Pesa Code
    payment_date TEXT DEFAULT CURRENT_TIMESTAMP,
    status TEXT DEFAULT 'SUCCESS', -- SUCCESS, FAILED, PENDING
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
    FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id)
);

CREATE TABLE payment_transactions (
    id TEXT PRIMARY KEY,
    business_id TEXT NOT NULL,
    branch_id TEXT NOT NULL,
    payment_method_id TEXT NOT NULL,
    transaction_type TEXT NOT NULL, -- IN (Sale), OUT (Expense/Refund)
    amount REAL NOT NULL,
    reference_id TEXT, -- Sale ID, Expense ID, etc.
    transaction_date TEXT DEFAULT CURRENT_TIMESTAMP,
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
    FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id)
);

CREATE TABLE payment_reconciliation (
    id TEXT PRIMARY KEY,
    branch_id TEXT NOT NULL,
    payment_method_id TEXT NOT NULL,
    reconciliation_date TEXT DEFAULT CURRENT_TIMESTAMP,
    expected_amount REAL NOT NULL,
    actual_amount REAL NOT NULL,
    difference REAL NOT NULL,
    employee_id TEXT NOT NULL,
    status TEXT DEFAULT 'CLOSED', -- OPEN, CLOSED
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
    FOREIGN KEY (branch_id) REFERENCES branches(id) ON DELETE CASCADE,
    FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id),
    FOREIGN KEY (employee_id) REFERENCES employees(id)
);
