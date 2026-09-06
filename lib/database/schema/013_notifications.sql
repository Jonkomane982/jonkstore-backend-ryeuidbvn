-- 013_notifications.sql
-- System and AI Notifications Management

CREATE TABLE notification_settings (
    id TEXT PRIMARY KEY,
    employee_id TEXT NOT NULL,
    notification_type TEXT NOT NULL, -- e.g., LOW_STOCK, DAILY_REPORT, SECURITY_ALERT
    is_enabled INTEGER DEFAULT 1,
    channel TEXT NOT NULL, -- IN_APP, EMAIL, PUSH, SMS
    -- Audit & Sync
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
    deleted_at TEXT,
    is_deleted INTEGER DEFAULT 0,
    sync_status TEXT DEFAULT 'PENDING',
    version INTEGER DEFAULT 1,
    created_by TEXT,
    updated_by TEXT,
    FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE,
    UNIQUE(employee_id, notification_type, channel)
);

CREATE TABLE notifications (
    id TEXT PRIMARY KEY,
    business_id TEXT NOT NULL,
    branch_id TEXT, -- Can be null for business-wide notifications
    employee_id TEXT, -- Target user, null for broadcast
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT NOT NULL, -- INFO, WARNING, SUCCESS, ERROR, AI
    priority TEXT DEFAULT 'NORMAL', -- LOW, NORMAL, HIGH, URGENT
    is_read INTEGER DEFAULT 0,
    read_at TEXT,
    action_url TEXT, -- Deep link for the app
    metadata TEXT, -- JSON payload for additional data
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
    FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE
);
