-- 006_products.sql
-- Products, Variants, Units, Prices, and Barcodes Management

CREATE TABLE product_units (
    id TEXT PRIMARY KEY,
    business_id TEXT NOT NULL,
    name TEXT NOT NULL, -- e.g., Piece, Kilogram, Litre, Box
    short_name TEXT NOT NULL, -- e.g., pc, kg, l, bx
    allow_decimal INTEGER DEFAULT 0,
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

CREATE TABLE products (
    id TEXT PRIMARY KEY,
    business_id TEXT NOT NULL,
    brand_id TEXT,
    unit_id TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    sku TEXT UNIQUE,
    type TEXT NOT NULL DEFAULT 'PHYSICAL', -- PHYSICAL, SERVICE, DIGITAL
    is_active INTEGER DEFAULT 1,
    track_inventory INTEGER DEFAULT 1,
    low_stock_threshold REAL DEFAULT 0,
    tax_id TEXT,
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
    FOREIGN KEY (brand_id) REFERENCES brands(id) ON DELETE SET NULL,
    FOREIGN KEY (unit_id) REFERENCES product_units(id),
    FOREIGN KEY (tax_id) REFERENCES taxes(id) ON DELETE SET NULL
);

CREATE TABLE product_categories (
    id TEXT PRIMARY KEY,
    product_id TEXT NOT NULL,
    category_id TEXT NOT NULL,
    subcategory_id TEXT,
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
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE,
    FOREIGN KEY (subcategory_id) REFERENCES subcategories(id) ON DELETE SET NULL,
    UNIQUE(product_id, category_id)
);

CREATE TABLE product_variants (
    id TEXT PRIMARY KEY,
    product_id TEXT NOT NULL,
    name TEXT NOT NULL, -- e.g., Color: Red, Size: XL
    sku TEXT UNIQUE,
    barcode TEXT, -- Primary barcode for this variant
    cost_price REAL DEFAULT 0,
    markup_percentage REAL DEFAULT 0,
    price REAL NOT NULL,
    weight REAL,
    image_url TEXT,
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
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
);

CREATE TABLE product_barcodes (
    id TEXT PRIMARY KEY,
    product_id TEXT NOT NULL,
    variant_id TEXT,
    barcode TEXT NOT NULL,
    type TEXT, -- e.g., EAN13, UPC, QR
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
    FOREIGN KEY (variant_id) REFERENCES product_variants(id) ON DELETE CASCADE,
    UNIQUE(barcode)
);

CREATE TABLE product_images (
    id TEXT PRIMARY KEY,
    product_id TEXT NOT NULL,
    variant_id TEXT,
    image_url TEXT NOT NULL,
    is_primary INTEGER DEFAULT 0,
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
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    FOREIGN KEY (variant_id) REFERENCES product_variants(id) ON DELETE CASCADE
);

CREATE TABLE product_prices (
    id TEXT PRIMARY KEY,
    product_id TEXT NOT NULL,
    variant_id TEXT,
    branch_id TEXT, -- Null means global price
    price REAL NOT NULL,
    start_date TEXT,
    end_date TEXT,
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
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    FOREIGN KEY (variant_id) REFERENCES product_variants(id) ON DELETE CASCADE,
    FOREIGN KEY (branch_id) REFERENCES branches(id) ON DELETE CASCADE
);
