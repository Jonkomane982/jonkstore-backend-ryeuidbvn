/// Static class containing the full, commercial-grade SQL schema for JonkStore POS.
/// Strictly formatted for production-grade stability on Web and Native.
class SchemaScripts {
  /// PRAGMAs for configuration. Skipped on Web to prevent crashes.
  static const List<String> onConfigureScripts = [
    "PRAGMA foreign_keys = ON",
    "PRAGMA journal_mode = WAL",
    "PRAGMA synchronous = NORMAL",
  ];

  /// The complete creation scripts for all tables, indexes, views, and triggers.
  /// Organized by module. Trailing semicolons removed for Web driver compatibility.
  static const List<String> onCreateScripts = [
    // --- 1. BUSINESS ---
    "CREATE TABLE currencies (id TEXT PRIMARY KEY, code TEXT NOT NULL UNIQUE, name TEXT NOT NULL, symbol TEXT NOT NULL, exchange_rate REAL DEFAULT 1.0, is_active INTEGER DEFAULT 1, created_at TEXT DEFAULT CURRENT_TIMESTAMP, updated_at TEXT DEFAULT CURRENT_TIMESTAMP, deleted_at TEXT, is_deleted INTEGER DEFAULT 0, sync_status TEXT DEFAULT 'PENDING', version INTEGER DEFAULT 1, created_by TEXT, updated_by TEXT)",
    "CREATE TABLE businesses (id TEXT PRIMARY KEY, name TEXT NOT NULL, tax_id TEXT, registration_number TEXT, email TEXT, phone TEXT, website TEXT, logo_url TEXT, currency_id TEXT NOT NULL, base_timezone TEXT DEFAULT 'UTC', is_active INTEGER DEFAULT 1, created_at TEXT DEFAULT CURRENT_TIMESTAMP, updated_at TEXT DEFAULT CURRENT_TIMESTAMP, deleted_at TEXT, is_deleted INTEGER DEFAULT 0, sync_status TEXT DEFAULT 'PENDING', version INTEGER DEFAULT 1, created_by TEXT, updated_by TEXT, FOREIGN KEY (currency_id) REFERENCES currencies(id))",
    "CREATE TABLE branches (id TEXT PRIMARY KEY, business_id TEXT NOT NULL, name TEXT NOT NULL, code TEXT UNIQUE, address TEXT, city TEXT, state TEXT, country TEXT, postal_code TEXT, phone TEXT, email TEXT, is_main_branch INTEGER DEFAULT 0, is_active INTEGER DEFAULT 1, created_at TEXT DEFAULT CURRENT_TIMESTAMP, updated_at TEXT DEFAULT CURRENT_TIMESTAMP, deleted_at TEXT, is_deleted INTEGER DEFAULT 0, sync_status TEXT DEFAULT 'PENDING', version INTEGER DEFAULT 1, created_by TEXT, updated_by TEXT, FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE)",
    "CREATE TABLE business_settings (id TEXT PRIMARY KEY, business_id TEXT NOT NULL, setting_key TEXT NOT NULL, setting_value TEXT, description TEXT, created_at TEXT DEFAULT CURRENT_TIMESTAMP, updated_at TEXT DEFAULT CURRENT_TIMESTAMP, deleted_at TEXT, is_deleted INTEGER DEFAULT 0, sync_status TEXT DEFAULT 'PENDING', version INTEGER DEFAULT 1, created_by TEXT, updated_by TEXT, FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE, UNIQUE(business_id, setting_key))",
    "CREATE TABLE taxes (id TEXT PRIMARY KEY, business_id TEXT NOT NULL, name TEXT NOT NULL, rate REAL NOT NULL, is_compound INTEGER DEFAULT 0, is_active INTEGER DEFAULT 1, created_at TEXT DEFAULT CURRENT_TIMESTAMP, updated_at TEXT DEFAULT CURRENT_TIMESTAMP, deleted_at TEXT, is_deleted INTEGER DEFAULT 0, sync_status TEXT DEFAULT 'PENDING', version INTEGER DEFAULT 1, created_by TEXT, updated_by TEXT, FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE, CHECK (rate >= 0))",

    // --- 2. OWNER & SECURITY ---
    "CREATE TABLE owner_profile (id TEXT PRIMARY KEY, business_id TEXT NOT NULL, firebase_uid TEXT UNIQUE, username TEXT UNIQUE, full_name TEXT, email TEXT, phone TEXT, profile_image_url TEXT, role TEXT DEFAULT 'owner', password_hash TEXT, is_verified INTEGER DEFAULT 0, created_at TEXT DEFAULT CURRENT_TIMESTAMP, updated_at TEXT DEFAULT CURRENT_TIMESTAMP, deleted_at TEXT, is_deleted INTEGER DEFAULT 0, sync_status TEXT DEFAULT 'PENDING', version INTEGER DEFAULT 1, created_by TEXT, updated_by TEXT, FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE)",
    "CREATE TABLE roles (id TEXT PRIMARY KEY, business_id TEXT NOT NULL, name TEXT NOT NULL, description TEXT, is_system_role INTEGER DEFAULT 0, created_at TEXT DEFAULT CURRENT_TIMESTAMP, updated_at TEXT DEFAULT CURRENT_TIMESTAMP, deleted_at TEXT, is_deleted INTEGER DEFAULT 0, sync_status TEXT DEFAULT 'PENDING', version INTEGER DEFAULT 1, created_by TEXT, updated_by TEXT, FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE, UNIQUE(business_id, name))",
    "CREATE TABLE permissions (id TEXT PRIMARY KEY, name TEXT NOT NULL, slug TEXT NOT NULL UNIQUE, module TEXT NOT NULL, description TEXT, created_at TEXT DEFAULT CURRENT_TIMESTAMP, updated_at TEXT DEFAULT CURRENT_TIMESTAMP, deleted_at TEXT, is_deleted INTEGER DEFAULT 0, sync_status TEXT DEFAULT 'PENDING', version INTEGER DEFAULT 1, created_by TEXT, updated_by TEXT)",
    "CREATE TABLE role_permissions (id TEXT PRIMARY KEY, role_id TEXT NOT NULL, permission_id TEXT NOT NULL, created_at TEXT DEFAULT CURRENT_TIMESTAMP, updated_at TEXT DEFAULT CURRENT_TIMESTAMP, deleted_at TEXT, is_deleted INTEGER DEFAULT 0, sync_status TEXT DEFAULT 'PENDING', version INTEGER DEFAULT 1, created_by TEXT, updated_by TEXT, FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE, FOREIGN KEY (permission_id) REFERENCES permissions(id) ON DELETE CASCADE, UNIQUE(role_id, permission_id))",
    "CREATE TABLE employees (id TEXT PRIMARY KEY, business_id TEXT NOT NULL, branch_id TEXT NOT NULL, role_id TEXT NOT NULL, first_name TEXT NOT NULL, last_name TEXT NOT NULL, email TEXT UNIQUE, phone TEXT UNIQUE, pin_hash TEXT, password_hash TEXT, is_active INTEGER DEFAULT 1, last_login_at TEXT, created_at TEXT DEFAULT CURRENT_TIMESTAMP, updated_at TEXT DEFAULT CURRENT_TIMESTAMP, deleted_at TEXT, is_deleted INTEGER DEFAULT 0, sync_status TEXT DEFAULT 'PENDING', version INTEGER DEFAULT 1, created_by TEXT, updated_by TEXT, FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE, FOREIGN KEY (branch_id) REFERENCES branches(id) ON DELETE CASCADE, FOREIGN KEY (role_id) REFERENCES roles(id))",

    // --- 3. CATALOG & SUPPLIERS ---
    "CREATE TABLE categories (id TEXT PRIMARY KEY, business_id TEXT NOT NULL, name TEXT NOT NULL, description TEXT, image_url TEXT, icon_data TEXT, is_active INTEGER DEFAULT 1, display_order INTEGER DEFAULT 0, created_at TEXT DEFAULT CURRENT_TIMESTAMP, updated_at TEXT DEFAULT CURRENT_TIMESTAMP, deleted_at TEXT, is_deleted INTEGER DEFAULT 0, sync_status TEXT DEFAULT 'PENDING', version INTEGER DEFAULT 1, created_by TEXT, updated_by TEXT, FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE)",
    "CREATE TABLE suppliers (id TEXT PRIMARY KEY, business_id TEXT NOT NULL, name TEXT NOT NULL, code TEXT UNIQUE, contactName TEXT, email TEXT, phone TEXT, address TEXT, notes TEXT, is_active INTEGER DEFAULT 1, created_at TEXT DEFAULT CURRENT_TIMESTAMP, updated_at TEXT DEFAULT CURRENT_TIMESTAMP, deleted_at TEXT, is_deleted INTEGER DEFAULT 0, sync_status TEXT DEFAULT 'PENDING', version INTEGER DEFAULT 1, created_by TEXT, updated_by TEXT, FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE)",
    "CREATE TABLE product_units (id TEXT PRIMARY KEY, business_id TEXT NOT NULL, name TEXT NOT NULL, short_name TEXT NOT NULL, created_at TEXT DEFAULT CURRENT_TIMESTAMP, updated_at TEXT DEFAULT CURRENT_TIMESTAMP, deleted_at TEXT, is_deleted INTEGER DEFAULT 0, sync_status TEXT DEFAULT 'PENDING', version INTEGER DEFAULT 1, created_by TEXT, updated_by TEXT, FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE)",
    "CREATE TABLE products (id TEXT PRIMARY KEY, business_id TEXT NOT NULL, unit_id TEXT NOT NULL, name TEXT NOT NULL, description TEXT, sku TEXT UNIQUE, type TEXT NOT NULL DEFAULT 'PHYSICAL', is_active INTEGER DEFAULT 1, track_inventory INTEGER DEFAULT 1, low_stock_threshold REAL DEFAULT 0, created_at TEXT DEFAULT CURRENT_TIMESTAMP, updated_at TEXT DEFAULT CURRENT_TIMESTAMP, deleted_at TEXT, is_deleted INTEGER DEFAULT 0, sync_status TEXT DEFAULT 'PENDING', version INTEGER DEFAULT 1, created_by TEXT, updated_by TEXT, FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE, FOREIGN KEY (unit_id) REFERENCES product_units(id))",
    "CREATE TABLE product_variants (id TEXT PRIMARY KEY, product_id TEXT NOT NULL, name TEXT NOT NULL, sku TEXT UNIQUE, barcode TEXT, cost_price REAL DEFAULT 0, price REAL NOT NULL, is_active INTEGER DEFAULT 1, created_at TEXT DEFAULT CURRENT_TIMESTAMP, updated_at TEXT DEFAULT CURRENT_TIMESTAMP, deleted_at TEXT, is_deleted INTEGER DEFAULT 0, sync_status TEXT DEFAULT 'PENDING', version INTEGER DEFAULT 1, created_by TEXT, updated_by TEXT, FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE)",

    // --- 4. INVENTORY ---
    "CREATE TABLE inventory (id TEXT PRIMARY KEY, product_id TEXT NOT NULL, variant_id TEXT, branch_id TEXT NOT NULL, quantity REAL NOT NULL DEFAULT 0, reserved_quantity REAL DEFAULT 0, low_stock_threshold REAL DEFAULT 10, created_at TEXT DEFAULT CURRENT_TIMESTAMP, updated_at TEXT DEFAULT CURRENT_TIMESTAMP, deleted_at TEXT, is_deleted INTEGER DEFAULT 0, sync_status TEXT DEFAULT 'PENDING', version INTEGER DEFAULT 1, created_by TEXT, updated_by TEXT, FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE, FOREIGN KEY (branch_id) REFERENCES branches(id) ON DELETE CASCADE, UNIQUE(product_id, variant_id, branch_id))",
    "CREATE TABLE inventory_transactions (id TEXT PRIMARY KEY, inventory_id TEXT NOT NULL, transaction_type TEXT NOT NULL, reference_id TEXT, quantity_change REAL NOT NULL, previous_quantity REAL NOT NULL, new_quantity REAL NOT NULL, reason TEXT, transaction_date TEXT DEFAULT CURRENT_TIMESTAMP, created_at TEXT DEFAULT CURRENT_TIMESTAMP, updated_at TEXT DEFAULT CURRENT_TIMESTAMP, deleted_at TEXT, is_deleted INTEGER DEFAULT 0, sync_status TEXT DEFAULT 'PENDING', version INTEGER DEFAULT 1, created_by TEXT, updated_by TEXT, FOREIGN KEY (inventory_id) REFERENCES inventory(id) ON DELETE CASCADE)",

    // --- 5. CUSTOMERS & SALES ---
    "CREATE TABLE customers (id TEXT PRIMARY KEY, business_id TEXT NOT NULL, first_name TEXT NOT NULL, last_name TEXT, email TEXT, phone TEXT, is_active INTEGER DEFAULT 1, created_at TEXT DEFAULT CURRENT_TIMESTAMP, updated_at TEXT DEFAULT CURRENT_TIMESTAMP, deleted_at TEXT, is_deleted INTEGER DEFAULT 0, sync_status TEXT DEFAULT 'PENDING', version INTEGER DEFAULT 1, created_by TEXT, updated_by TEXT, FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE)",
    "CREATE TABLE sales (id TEXT PRIMARY KEY, business_id TEXT NOT NULL, branch_id TEXT NOT NULL, customer_id TEXT, employee_id TEXT NOT NULL, invoice_number TEXT UNIQUE, sale_date TEXT DEFAULT CURRENT_TIMESTAMP, status TEXT NOT NULL DEFAULT 'COMPLETED', total_amount REAL NOT NULL DEFAULT 0, paid_amount REAL NOT NULL DEFAULT 0, created_at TEXT DEFAULT CURRENT_TIMESTAMP, updated_at TEXT DEFAULT CURRENT_TIMESTAMP, deleted_at TEXT, is_deleted INTEGER DEFAULT 0, sync_status TEXT DEFAULT 'PENDING', version INTEGER DEFAULT 1, created_by TEXT, updated_by TEXT, FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE, FOREIGN KEY (branch_id) REFERENCES branches(id) ON DELETE CASCADE, FOREIGN KEY (employee_id) REFERENCES employees(id))",
    "CREATE TABLE sale_items (id TEXT PRIMARY KEY, sale_id TEXT NOT NULL, product_id TEXT NOT NULL, variant_id TEXT, sku TEXT, name TEXT NOT NULL, quantity REAL NOT NULL, unit_price REAL NOT NULL, cost_price REAL NOT NULL, total_amount REAL NOT NULL, is_returned INTEGER DEFAULT 0, return_quantity REAL DEFAULT 0, created_at TEXT DEFAULT CURRENT_TIMESTAMP, updated_at TEXT DEFAULT CURRENT_TIMESTAMP, deleted_at TEXT, is_deleted INTEGER DEFAULT 0, sync_status TEXT DEFAULT 'PENDING', version INTEGER DEFAULT 1, created_by TEXT, updated_by TEXT, FOREIGN KEY (sale_id) REFERENCES sales(id) ON DELETE CASCADE, FOREIGN KEY (product_id) REFERENCES products(id))",

    // --- 6. SYSTEM & AUDIT ---
    "CREATE TABLE audit_logs (id TEXT PRIMARY KEY, table_name TEXT NOT NULL, record_id TEXT NOT NULL, action TEXT NOT NULL, old_values TEXT, new_values TEXT, employee_id TEXT, changed_at TEXT DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY (employee_id) REFERENCES employees(id))",
    "CREATE TABLE app_settings (id TEXT PRIMARY KEY, setting_group TEXT NOT NULL, setting_key TEXT NOT NULL, setting_value TEXT, updated_at TEXT DEFAULT CURRENT_TIMESTAMP, UNIQUE(setting_group, setting_key))",
    "CREATE TABLE system_settings (id TEXT PRIMARY KEY, config_name TEXT NOT NULL UNIQUE, config_value TEXT, data_type TEXT DEFAULT 'STRING', last_updated_at TEXT DEFAULT CURRENT_TIMESTAMP)",

    // --- 7. INDEXES & VIEWS ---
    "CREATE INDEX idx_branches_business_id ON branches(business_id)",
    "CREATE INDEX idx_employees_branch_id ON employees(branch_id)",
    "CREATE INDEX idx_inventory_branch_product ON inventory(branch_id, product_id)",
    "CREATE INDEX idx_products_sku ON products(sku)",
    "CREATE INDEX idx_sales_date ON sales(sale_date)",
    "CREATE INDEX idx_sale_items_sale_id ON sale_items(sale_id)",
    "CREATE INDEX idx_suppliers_name ON suppliers(name)",
    "CREATE INDEX idx_suppliers_code ON suppliers(code)",
    "CREATE INDEX idx_suppliers_phone ON suppliers(phone)",
    "CREATE INDEX idx_suppliers_active ON suppliers(is_active) WHERE is_deleted = 0",
    "CREATE INDEX idx_categories_name ON categories(name)",
    "CREATE VIEW daily_sales_summary AS SELECT branch_id, DATE(sale_date) as report_date, COUNT(id) as total_transactions, SUM(total_amount) as net_sales FROM sales WHERE is_deleted = 0 AND status = 'COMPLETED' GROUP BY branch_id, DATE(sale_date)",

    // --- 8. TRIGGERS ---
    "CREATE TRIGGER trg_prevent_negative_stock BEFORE UPDATE ON inventory WHEN NEW.quantity < 0 BEGIN SELECT RAISE(ABORT, 'Insufficient stock level.'); END",

    // --- 9. SEED DATA ---
    "INSERT INTO currencies (id, code, name, symbol, exchange_rate, is_active) VALUES ('CUR001', 'KES', 'Kenyan Shilling', 'KES', 1.0, 1)",
    "INSERT INTO app_settings (id, setting_group, setting_key, setting_value) VALUES ('SYS001', 'system', 'app_version', '1.0.0')",
  ];
}
