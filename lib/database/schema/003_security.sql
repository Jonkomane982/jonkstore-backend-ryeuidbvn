-- 003_security.sql
-- Roles, Permissions, Employees and Security Management

CREATE TABLE roles (
    id TEXT PRIMARY KEY,
    business_id TEXT NOT NULL,
    name TEXT NOT NULL, -- e.g., Admin, Cashier, Manager
    description TEXT,
    is_system_role INTEGER DEFAULT 0, -- Prevents deletion of core roles
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
    UNIQUE(business_id, name)
);

CREATE TABLE permissions (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL, -- Human readable
    slug TEXT NOT NULL UNIQUE, -- e.g., sales.create, inventory.edit
    module TEXT NOT NULL, -- e.g., Sales, Inventory, Settings
    description TEXT,
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

CREATE TABLE role_permissions (
    id TEXT PRIMARY KEY,
    role_id TEXT NOT NULL,
    permission_id TEXT NOT NULL,
    -- Audit & Sync
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
    deleted_at TEXT,
    is_deleted INTEGER DEFAULT 0,
    sync_status TEXT DEFAULT 'PENDING',
    version INTEGER DEFAULT 1,
    created_by TEXT,
    updated_by TEXT,
    FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE,
    FOREIGN KEY (permission_id) REFERENCES permissions(id) ON DELETE CASCADE,
    UNIQUE(role_id, permission_id)
);

CREATE TABLE employees (
    id TEXT PRIMARY KEY,
    business_id TEXT NOT NULL,
    branch_id TEXT NOT NULL,
    role_id TEXT NOT NULL,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    email TEXT UNIQUE,
    phone TEXT UNIQUE,
    pin_hash TEXT, -- For quick POS login
    password_hash TEXT, -- For management portal login
    is_active INTEGER DEFAULT 1,
    last_login_at TEXT,
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
    FOREIGN KEY (role_id) REFERENCES roles(id)
);

CREATE TABLE employee_permissions (
    id TEXT PRIMARY KEY,
    employee_id TEXT NOT NULL,
    permission_id TEXT NOT NULL,
    is_granted INTEGER DEFAULT 1, -- Can be used to explicitly deny or grant override
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
    FOREIGN KEY (permission_id) REFERENCES permissions(id) ON DELETE CASCADE,
    UNIQUE(employee_id, permission_id)
);

CREATE TABLE owner_profile (
    id TEXT PRIMARY KEY,
    business_id TEXT NOT NULL,
    firebase_uid TEXT UNIQUE,
    username TEXT UNIQUE,
    full_name TEXT,
    email TEXT,
    phone TEXT,
    profile_image_url TEXT,
    role TEXT DEFAULT 'owner',
    password_hash TEXT,
    is_verified INTEGER DEFAULT 0,
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

CREATE TABLE authorized_devices (
    id TEXT PRIMARY KEY,
    employee_id TEXT, -- Can be null if device is pending assignment
    device_identifier TEXT NOT NULL UNIQUE, -- e.g., Android ID, UUID
    device_name TEXT,
    device_model TEXT,
    os_version TEXT,
    is_trusted INTEGER DEFAULT 0,
    last_used_at TEXT,
    -- Audit & Sync
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
    deleted_at TEXT,
    is_deleted INTEGER DEFAULT 0,
    sync_status TEXT DEFAULT 'PENDING',
    version INTEGER DEFAULT 1,
    created_by TEXT,
    updated_by TEXT,
    FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE SET NULL
);

CREATE TABLE login_history (
    id TEXT PRIMARY KEY,
    employee_id TEXT NOT NULL,
    device_id TEXT,
    ip_address TEXT,
    login_at TEXT DEFAULT CURRENT_TIMESTAMP,
    logout_at TEXT,
    status TEXT NOT NULL, -- SUCCESS, FAILED
    failure_reason TEXT,
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
    FOREIGN KEY (device_id) REFERENCES authorized_devices(id) ON DELETE SET NULL
);
