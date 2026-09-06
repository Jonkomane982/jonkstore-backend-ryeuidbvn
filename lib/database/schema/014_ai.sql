-- 014_ai.sql
-- AI Recommendations, Business Health, and Price Predictions

CREATE TABLE ai_recommendations (
    id TEXT PRIMARY KEY,
    business_id TEXT NOT NULL,
    branch_id TEXT,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    category TEXT NOT NULL, -- INVENTORY, SALES, EXPENSES, CUSTOMERS
    confidence_score REAL DEFAULT 0,
    impact_level TEXT DEFAULT 'MEDIUM', -- LOW, MEDIUM, HIGH
    is_applied INTEGER DEFAULT 0,
    metadata TEXT, -- JSON for action details
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
    FOREIGN KEY (branch_id) REFERENCES branches(id) ON DELETE CASCADE
);

CREATE TABLE business_health (
    id TEXT PRIMARY KEY,
    business_id TEXT NOT NULL,
    branch_id TEXT,
    health_score REAL NOT NULL, -- 0 to 100
    metric_date TEXT DEFAULT CURRENT_TIMESTAMP,
    metrics_json TEXT, -- Detailed breakdown of scores
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
    FOREIGN KEY (branch_id) REFERENCES branches(id) ON DELETE CASCADE
);

CREATE TABLE price_predictions (
    id TEXT PRIMARY KEY,
    product_id TEXT NOT NULL,
    variant_id TEXT,
    predicted_price REAL NOT NULL,
    prediction_date TEXT DEFAULT CURRENT_TIMESTAMP,
    confidence_interval TEXT, -- e.g., "±5.0"
    reasoning TEXT,
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
    FOREIGN KEY (variant_id) REFERENCES product_variants(id) ON DELETE CASCADE
);
