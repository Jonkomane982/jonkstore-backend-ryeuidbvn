-- 012_expenses.sql
-- Expense Categories and Expenses Management

CREATE TABLE expense_categories (
    id TEXT PRIMARY KEY,
    business_id TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
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

CREATE TABLE expenses (
    id TEXT PRIMARY KEY,
    business_id TEXT NOT NULL,
    branch_id TEXT NOT NULL,
    category_id TEXT NOT NULL,
    employee_id TEXT NOT NULL,
    payment_method_id TEXT,
    amount REAL NOT NULL,
    expense_date TEXT DEFAULT CURRENT_TIMESTAMP,
    reference_number TEXT,
    supplier_id TEXT, -- If the expense is paid to a specific supplier
    description TEXT,
    receipt_image_url TEXT,
    status TEXT DEFAULT 'APPROVED', -- PENDING, APPROVED, REJECTED
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
    FOREIGN KEY (category_id) REFERENCES expense_categories(id),
    FOREIGN KEY (employee_id) REFERENCES employees(id),
    FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id),
    FOREIGN KEY (supplier_id) REFERENCES suppliers(id) ON DELETE SET NULL,
    CHECK (amount > 0)
);
