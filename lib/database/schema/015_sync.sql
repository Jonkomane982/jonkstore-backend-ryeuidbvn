-- 015_sync.sql
-- Sync, Audit, System, and Report Tables

-- SYNC TABLES
CREATE TABLE sync_queue (
    id TEXT PRIMARY KEY,
    table_name TEXT NOT NULL,
    record_id TEXT NOT NULL,
    operation TEXT NOT NULL, -- INSERT, UPDATE, DELETE
    priority INTEGER DEFAULT 0,
    attempts INTEGER DEFAULT 0,
    last_attempt_at TEXT,
    error_message TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE sync_logs (
    id TEXT PRIMARY KEY,
    start_at TEXT NOT NULL,
    end_at TEXT,
    status TEXT NOT NULL, -- SUCCESS, FAILED, PARTIAL
    records_synced INTEGER DEFAULT 0,
    errors_count INTEGER DEFAULT 0,
    details TEXT -- JSON summary
);

CREATE TABLE sync_conflicts (
    id TEXT PRIMARY KEY,
    table_name TEXT NOT NULL,
    record_id TEXT NOT NULL,
    local_data TEXT NOT NULL, -- JSON
    server_data TEXT NOT NULL, -- JSON
    resolved_at TEXT,
    resolution_strategy TEXT, -- LOCAL_WINS, SERVER_WINS, MANUAL
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- AUDIT TABLES
CREATE TABLE audit_logs (
    id TEXT PRIMARY KEY,
    table_name TEXT NOT NULL,
    record_id TEXT NOT NULL,
    action TEXT NOT NULL, -- INSERT, UPDATE, DELETE
    old_values TEXT, -- JSON
    new_values TEXT, -- JSON
    employee_id TEXT,
    changed_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (employee_id) REFERENCES employees(id)
);

CREATE TABLE activity_logs (
    id TEXT PRIMARY KEY,
    employee_id TEXT NOT NULL,
    branch_id TEXT,
    activity_type TEXT NOT NULL, -- e.g., POS_OPEN, POS_CLOSE, DRAWER_OPEN, PRICE_CHANGE
    description TEXT,
    metadata TEXT, -- JSON
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (employee_id) REFERENCES employees(id)
);

-- SYSTEM TABLES
CREATE TABLE app_settings (
    id TEXT PRIMARY KEY,
    setting_group TEXT NOT NULL,
    setting_key TEXT NOT NULL,
    setting_value TEXT,
    is_encrypted INTEGER DEFAULT 0,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(setting_group, setting_key)
);

CREATE TABLE system_settings (
    id TEXT PRIMARY KEY,
    config_name TEXT NOT NULL UNIQUE,
    config_value TEXT,
    data_type TEXT DEFAULT 'STRING', -- STRING, INTEGER, BOOLEAN, JSON
    last_updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE backup_history (
    id TEXT PRIMARY KEY,
    file_path TEXT NOT NULL,
    file_size INTEGER,
    backup_type TEXT NOT NULL, -- AUTO, MANUAL
    status TEXT NOT NULL,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- REPORT TABLES (Aggregated snapshots for performance)
CREATE TABLE daily_reports (
    id TEXT PRIMARY KEY,
    branch_id TEXT NOT NULL,
    report_date TEXT NOT NULL,
    total_sales REAL DEFAULT 0,
    total_profit REAL DEFAULT 0,
    total_expenses REAL DEFAULT 0,
    total_tax REAL DEFAULT 0,
    sales_count INTEGER DEFAULT 0,
    metadata TEXT, -- JSON breakdown
    FOREIGN KEY (branch_id) REFERENCES branches(id),
    UNIQUE(branch_id, report_date)
);

CREATE TABLE monthly_reports (
    id TEXT PRIMARY KEY,
    branch_id TEXT NOT NULL,
    report_month TEXT NOT NULL, -- YYYY-MM
    total_sales REAL DEFAULT 0,
    total_profit REAL DEFAULT 0,
    total_expenses REAL DEFAULT 0,
    total_tax REAL DEFAULT 0,
    sales_count INTEGER DEFAULT 0,
    FOREIGN KEY (branch_id) REFERENCES branches(id),
    UNIQUE(branch_id, report_month)
);

CREATE TABLE yearly_reports (
    id TEXT PRIMARY KEY,
    business_id TEXT NOT NULL,
    report_year TEXT NOT NULL, -- YYYY
    total_sales REAL DEFAULT 0,
    total_profit REAL DEFAULT 0,
    total_expenses REAL DEFAULT 0,
    total_tax REAL DEFAULT 0,
    FOREIGN KEY (business_id) REFERENCES businesses(id),
    UNIQUE(business_id, report_year)
);
