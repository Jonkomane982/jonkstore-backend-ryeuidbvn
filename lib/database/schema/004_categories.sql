-- 004_categories.sql
-- Categories and Subcategories Management

CREATE TABLE categories (
    id TEXT PRIMARY KEY,
    business_id TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    image_url TEXT,
    icon_data TEXT, -- Can store icon name or SVG
    is_active INTEGER DEFAULT 1,
    display_order INTEGER DEFAULT 0,
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

CREATE TABLE subcategories (
    id TEXT PRIMARY KEY,
    category_id TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    is_active INTEGER DEFAULT 1,
    display_order INTEGER DEFAULT 0,
    -- Audit & Sync
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
    deleted_at TEXT,
    is_deleted INTEGER DEFAULT 0,
    sync_status TEXT DEFAULT 'PENDING',
    version INTEGER DEFAULT 1,
    created_by TEXT,
    updated_by TEXT,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
);
