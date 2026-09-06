-- ============================================================================
-- JONKSTORE POS - PRIMARY OPERATIONAL POSTGRESQL DATABASE SCHEMA
-- Version: 5.1.1 (Production Hardened & RLS Corrected)
-- Principal Database Architect: Final Operational Release
-- ============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 001. EXTENSIONS
-- -----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gist";

-- -----------------------------------------------------------------------------
-- 002. TYPES AND ENUMERATIONS
-- -----------------------------------------------------------------------------
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'sync_status_type') THEN
        CREATE TYPE sync_status_type AS ENUM ('PENDING', 'SYNCED', 'CONFLICT', 'FAILED');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'product_type') THEN
        CREATE TYPE product_type AS ENUM ('PHYSICAL', 'SERVICE', 'DIGITAL');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'purchase_status') THEN
        CREATE TYPE purchase_status AS ENUM ('DRAFT', 'PENDING', 'PARTIAL', 'RECEIVED', 'CANCELLED');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'sale_status') THEN
        CREATE TYPE sale_status AS ENUM ('DRAFT', 'PENDING', 'COMPLETED', 'CANCELLED', 'RETURNED', 'PARTIALLY_RETURNED');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'inventory_transaction_type') THEN
        CREATE TYPE inventory_transaction_type AS ENUM ('PURCHASE', 'SALE', 'RETURN_CUSTOMER', 'RETURN_SUPPLIER', 'DAMAGE', 'ADJUSTMENT', 'STOCK_COUNT', 'TRANSFER_IN', 'TRANSFER_OUT');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'runner_fee_allocation_method') THEN
        CREATE TYPE runner_fee_allocation_method AS ENUM ('PROPORTIONAL_BY_COST', 'EQUAL');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_method_type') THEN
        CREATE TYPE payment_method_type AS ENUM ('CASH', 'CARD', 'MOBILE_MONEY', 'BANK_TRANSFER', 'OTHER');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_status') THEN
        CREATE TYPE payment_status AS ENUM ('PENDING', 'AUTHORIZED', 'CAPTURED', 'REFUNDED', 'FAILED', 'REVERSED');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'severity_level') THEN
        CREATE TYPE severity_level AS ENUM ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL');
    END IF;
END $$;

-- -----------------------------------------------------------------------------
-- 003. CORE INFRASTRUCTURE
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS businesses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    tax_id TEXT,
    industry TEXT,
    logo_url TEXT,
    website TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    version INTEGER DEFAULT 1,
    source_id UUID -- For offline creation tracking
);

CREATE TABLE IF NOT EXISTS branches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    code TEXT,
    address TEXT,
    phone TEXT,
    is_main_branch BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    version INTEGER DEFAULT 1,
    source_id UUID,
    UNIQUE(id, business_id)
);

CREATE TABLE IF NOT EXISTS currencies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    code VARCHAR(3) NOT NULL,
    symbol VARCHAR(5) NOT NULL,
    name TEXT NOT NULL,
    is_base_currency BOOLEAN DEFAULT FALSE,
    exchange_rate NUMERIC(19, 6) DEFAULT 1.0 CHECK (exchange_rate > 0),
    UNIQUE(business_id, code),
    UNIQUE(id, business_id)
);

CREATE TABLE IF NOT EXISTS business_settings (
    business_id UUID PRIMARY KEY REFERENCES businesses(id) ON DELETE CASCADE,
    timezone TEXT DEFAULT 'UTC',
    date_format TEXT DEFAULT 'YYYY-MM-DD',
    currency_id UUID,
    low_stock_threshold_default NUMERIC(15, 3) DEFAULT 10 CHECK (low_stock_threshold_default >= 0),
    enable_loyalty BOOLEAN DEFAULT FALSE,
    loyalty_rate NUMERIC(15, 4) DEFAULT 0.01 CHECK (loyalty_rate >= 0),
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_settings_currency_tenant FOREIGN KEY (currency_id, business_id) REFERENCES currencies(id, business_id)
);

CREATE TABLE IF NOT EXISTS receipt_settings (
    branch_id UUID PRIMARY KEY,
    business_id UUID NOT NULL,
    header_text TEXT,
    footer_text TEXT,
    show_logo BOOLEAN DEFAULT TRUE,
    show_tax_details BOOLEAN DEFAULT TRUE,
    show_customer_info BOOLEAN DEFAULT TRUE,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_receipt_branch_tenant FOREIGN KEY (branch_id, business_id) REFERENCES branches(id, business_id)
);

CREATE TABLE IF NOT EXISTS business_hours (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    branch_id UUID NOT NULL,
    business_id UUID NOT NULL,
    day_of_week INTEGER NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
    open_time TIME,
    close_time TIME,
    is_closed BOOLEAN DEFAULT FALSE,
    CONSTRAINT fk_hours_branch_tenant FOREIGN KEY (branch_id, business_id) REFERENCES branches(id, business_id),
    UNIQUE(branch_id, day_of_week)
);

CREATE TABLE IF NOT EXISTS taxes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    rate NUMERIC(7, 6) NOT NULL CHECK (rate >= 0 AND rate <= 1.0),
    is_compound BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(id, business_id)
);

-- -----------------------------------------------------------------------------
-- 004. IDENTITY & SECURITY
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    firebase_uid TEXT UNIQUE NOT NULL,
    username TEXT UNIQUE,
    email TEXT UNIQUE NOT NULL,
    role_name TEXT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS owner_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    phone TEXT,
    UNIQUE(user_id, business_id)
);

CREATE TABLE IF NOT EXISTS roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    slug TEXT NOT NULL,
    is_system_role BOOLEAN DEFAULT FALSE,
    UNIQUE(id, business_id),
    UNIQUE(business_id, slug)
);

CREATE TABLE IF NOT EXISTS permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    slug TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    module TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS role_permissions (
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE IF NOT EXISTS employees (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    user_id UUID UNIQUE REFERENCES users(id) ON DELETE SET NULL,
    role_id UUID NOT NULL,
    branch_id UUID NOT NULL,
    employee_code TEXT NOT NULL,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    version INTEGER DEFAULT 1,
    CONSTRAINT fk_employee_role_tenant FOREIGN KEY (role_id, business_id) REFERENCES roles(id, business_id),
    CONSTRAINT fk_employee_branch_tenant FOREIGN KEY (branch_id, business_id) REFERENCES branches(id, business_id),
    UNIQUE(business_id, employee_code)
);

CREATE TABLE IF NOT EXISTS employee_permissions (
    employee_id UUID NOT NULL,
    business_id UUID NOT NULL,
    permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    PRIMARY KEY (employee_id, permission_id),
    CONSTRAINT fk_ep_employee_tenant FOREIGN KEY (employee_id, business_id) REFERENCES employees(id, business_id)
);

CREATE TABLE IF NOT EXISTS authorized_devices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    branch_id UUID,
    device_identifier TEXT NOT NULL,
    device_name TEXT,
    os_platform TEXT,
    last_access_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    is_revoked BOOLEAN DEFAULT FALSE,
    CONSTRAINT fk_device_branch_tenant FOREIGN KEY (branch_id, business_id) REFERENCES branches(id, business_id),
    UNIQUE(business_id, device_identifier)
);

CREATE TABLE IF NOT EXISTS login_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_id UUID REFERENCES authorized_devices(id) ON DELETE SET NULL,
    login_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    ip_address INET,
    user_agent TEXT
);

CREATE TABLE IF NOT EXISTS security_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    device_id UUID REFERENCES authorized_devices(id) ON DELETE SET NULL,
    event_type TEXT NOT NULL,
    severity severity_level DEFAULT 'MEDIUM',
    details JSONB,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS otps (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email TEXT NOT NULL,
    otp_code TEXT NOT NULL,
    purpose TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    verified_at TIMESTAMPTZ,
    is_used BOOLEAN DEFAULT FALSE
);

-- -----------------------------------------------------------------------------
-- 005. CATALOG & PRODUCTS
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    parent_id UUID,
    is_active BOOLEAN DEFAULT TRUE,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    version INTEGER DEFAULT 1,
    source_id UUID,
    CONSTRAINT fk_category_parent_tenant FOREIGN KEY (parent_id, business_id) REFERENCES categories(id, business_id),
    UNIQUE(id, business_id)
);

CREATE TABLE IF NOT EXISTS brands (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    is_deleted BOOLEAN DEFAULT FALSE,
    version INTEGER DEFAULT 1,
    source_id UUID,
    UNIQUE(id, business_id),
    UNIQUE(business_id, name)
);

CREATE TABLE IF NOT EXISTS product_units (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    short_name VARCHAR(10),
    is_active BOOLEAN DEFAULT TRUE,
    is_deleted BOOLEAN DEFAULT FALSE,
    version INTEGER DEFAULT 1,
    source_id UUID,
    UNIQUE(id, business_id),
    UNIQUE(business_id, name)
);

CREATE TABLE IF NOT EXISTS products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    category_id UUID NOT NULL,
    brand_id UUID,
    unit_id UUID,
    tax_id UUID,
    name TEXT NOT NULL,
    sku TEXT NOT NULL,
    description TEXT,
    type product_type DEFAULT 'PHYSICAL',
    selling_price NUMERIC(19, 4) NOT NULL DEFAULT 0 CHECK (selling_price >= 0),
    min_stock_level NUMERIC(15, 3) DEFAULT 0 CHECK (min_stock_level >= 0),
    track_inventory BOOLEAN DEFAULT TRUE,
    is_active BOOLEAN DEFAULT TRUE,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    version INTEGER DEFAULT 1,
    source_id UUID,
    CONSTRAINT fk_product_category_tenant FOREIGN KEY (category_id, business_id) REFERENCES categories(id, business_id),
    CONSTRAINT fk_product_brand_tenant FOREIGN KEY (brand_id, business_id) REFERENCES brands(id, business_id),
    CONSTRAINT fk_product_unit_tenant FOREIGN KEY (unit_id, business_id) REFERENCES product_units(id, business_id),
    CONSTRAINT fk_product_tax_tenant FOREIGN KEY (tax_id, business_id) REFERENCES taxes(id, business_id),
    UNIQUE(id, business_id),
    UNIQUE(business_id, sku)
);

CREATE TABLE IF NOT EXISTS product_barcodes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    product_id UUID NOT NULL,
    barcode TEXT NOT NULL,
    type TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    version INTEGER DEFAULT 1,
    source_id UUID,
    CONSTRAINT fk_barcode_product_tenant FOREIGN KEY (product_id, business_id) REFERENCES products(id, business_id),
    UNIQUE(business_id, barcode)
);

CREATE TABLE IF NOT EXISTS product_images (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    product_id UUID NOT NULL,
    image_url TEXT NOT NULL,
    is_primary BOOLEAN DEFAULT FALSE,
    sort_order INTEGER DEFAULT 0,
    CONSTRAINT fk_image_product_tenant FOREIGN KEY (product_id, business_id) REFERENCES products(id, business_id)
);

CREATE TABLE IF NOT EXISTS product_variants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    product_id UUID NOT NULL,
    name TEXT NOT NULL,
    sku_suffix TEXT,
    price_adjustment NUMERIC(19, 4) DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    version INTEGER DEFAULT 1,
    source_id UUID,
    CONSTRAINT fk_variant_product_tenant FOREIGN KEY (product_id, business_id) REFERENCES products(id, business_id),
    UNIQUE(id, business_id)
);

CREATE TABLE IF NOT EXISTS product_prices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    product_id UUID NOT NULL,
    variant_id UUID,
    branch_id UUID,
    price NUMERIC(19, 4) NOT NULL CHECK (price >= 0),
    cost_price NUMERIC(19, 4) CHECK (cost_price >= 0),
    start_date TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    end_date TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT TRUE,
    source_id UUID,
    CONSTRAINT fk_price_product_tenant FOREIGN KEY (product_id, business_id) REFERENCES products(id, business_id),
    CONSTRAINT fk_price_variant_tenant FOREIGN KEY (variant_id, business_id) REFERENCES product_variants(id, business_id),
    CONSTRAINT fk_price_branch_tenant FOREIGN KEY (branch_id, business_id) REFERENCES branches(id, business_id),
    CONSTRAINT no_overlapping_prices EXCLUDE USING gist (
        product_id WITH =,
        coalesce(variant_id, '00000000-0000-0000-0000-000000000000') WITH =,
        coalesce(branch_id, '00000000-0000-0000-0000-000000000000') WITH =,
        tstzrange(start_date, coalesce(end_date, 'infinity'), '[]') WITH &&
    )
);

-- -----------------------------------------------------------------------------
-- 006. SUPPLIERS
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS suppliers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    supplier_code TEXT NOT NULL,
    contact_name TEXT,
    email TEXT,
    phone TEXT,
    current_balance NUMERIC(19, 4) DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    version INTEGER DEFAULT 1,
    source_id UUID,
    UNIQUE(id, business_id),
    UNIQUE(business_id, supplier_code)
);

CREATE TABLE IF NOT EXISTS product_suppliers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    product_id UUID NOT NULL,
    supplier_id UUID NOT NULL,
    supplier_sku TEXT,
    buying_cost NUMERIC(19, 4) CHECK (buying_cost >= 0),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    version INTEGER DEFAULT 1,
    source_id UUID,
    CONSTRAINT fk_ps_product_tenant FOREIGN KEY (product_id, business_id) REFERENCES products(id, business_id),
    CONSTRAINT fk_ps_supplier_tenant FOREIGN KEY (supplier_id, business_id) REFERENCES suppliers(id, business_id),
    UNIQUE(product_id, supplier_id)
);

CREATE TABLE IF NOT EXISTS supplier_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    supplier_id UUID NOT NULL,
    transaction_type TEXT NOT NULL,
    amount NUMERIC(19, 4) NOT NULL,
    balance_after NUMERIC(19, 4) NOT NULL,
    reference_id UUID,
    reference_type TEXT,
    transaction_date TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    notes TEXT,
    source_id UUID,
    CONSTRAINT fk_supplier_tx_tenant FOREIGN KEY (supplier_id, business_id) REFERENCES suppliers(id, business_id),
    UNIQUE(business_id, source_id)
);

-- -----------------------------------------------------------------------------
-- 007. PROCUREMENT (PURCHASES)
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS purchase_orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL,
    supplier_id UUID NOT NULL,
    order_number TEXT NOT NULL,
    purchase_date TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status purchase_status DEFAULT 'PENDING',
    subtotal NUMERIC(19, 4) NOT NULL DEFAULT 0 CHECK (subtotal >= 0),
    tax_total NUMERIC(19, 4) DEFAULT 0 CHECK (tax_total >= 0),
    runner_fee NUMERIC(19, 4) DEFAULT 0 CHECK (runner_fee >= 0),
    allocation_method runner_fee_allocation_method DEFAULT 'PROPORTIONAL_BY_COST',
    total_amount NUMERIC(19, 4) NOT NULL DEFAULT 0 CHECK (total_amount >= 0),
    paid_amount NUMERIC(19, 4) DEFAULT 0,
    notes TEXT,
    created_by UUID REFERENCES users(id),
    source_id UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT fk_po_branch_tenant FOREIGN KEY (branch_id, business_id) REFERENCES branches(id, business_id),
    CONSTRAINT fk_po_supplier_tenant FOREIGN KEY (supplier_id, business_id) REFERENCES suppliers(id, business_id),
    UNIQUE(id, business_id),
    UNIQUE(business_id, order_number),
    UNIQUE(business_id, source_id)
);

CREATE TABLE IF NOT EXISTS purchase_order_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL,
    purchase_order_id UUID NOT NULL,
    product_id UUID NOT NULL,
    quantity NUMERIC(15, 3) NOT NULL CHECK (quantity > 0),
    received_quantity NUMERIC(15, 3) DEFAULT 0 CHECK (received_quantity >= 0),
    unit_buying_price NUMERIC(19, 4) NOT NULL CHECK (unit_buying_price >= 0),
    allocated_runner_fee NUMERIC(19, 4) DEFAULT 0,
    landed_unit_cost NUMERIC(19, 4) NOT NULL DEFAULT 0,
    total_buying_price NUMERIC(19, 4) NOT NULL DEFAULT 0,
    CONSTRAINT fk_poi_order_tenant FOREIGN KEY (purchase_order_id, business_id) REFERENCES purchase_orders(id, business_id),
    CONSTRAINT fk_poi_product_tenant FOREIGN KEY (product_id, business_id) REFERENCES products(id, business_id)
);

CREATE TABLE IF NOT EXISTS runner_fees (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    purchase_order_id UUID NOT NULL,
    amount NUMERIC(19, 4) NOT NULL CHECK (amount >= 0),
    runner_name TEXT,
    notes TEXT,
    payment_status TEXT DEFAULT 'PENDING',
    payment_date TIMESTAMPTZ,
    CONSTRAINT fk_runner_po_tenant FOREIGN KEY (purchase_order_id, business_id) REFERENCES purchase_orders(id, business_id)
);

-- -----------------------------------------------------------------------------
-- 008. FULFILLMENT (INVENTORY)
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS inventory (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL,
    product_id UUID NOT NULL,
    quantity NUMERIC(15, 3) NOT NULL DEFAULT 0,
    reserved_quantity NUMERIC(15, 3) DEFAULT 0,
    weighted_average_cost NUMERIC(19, 4) DEFAULT 0 CHECK (weighted_average_cost >= 0),
    bin_location TEXT,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    version INTEGER DEFAULT 1,
    CONSTRAINT fk_inv_branch_tenant FOREIGN KEY (branch_id, business_id) REFERENCES branches(id, business_id),
    CONSTRAINT fk_inv_product_tenant FOREIGN KEY (product_id, business_id) REFERENCES products(id, business_id),
    UNIQUE(branch_id, product_id),
    UNIQUE(id, business_id)
);

CREATE TABLE IF NOT EXISTS inventory_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL,
    inventory_id UUID NOT NULL,
    product_id UUID NOT NULL,
    transaction_type inventory_transaction_type NOT NULL,
    reference_id UUID NOT NULL,
    reference_type TEXT NOT NULL,
    previous_quantity NUMERIC(15, 3) NOT NULL,
    quantity_change NUMERIC(15, 3) NOT NULL,
    resulting_quantity NUMERIC(15, 3) NOT NULL,
    unit_cost NUMERIC(19, 4),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    source_id UUID,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_it_inv_tenant FOREIGN KEY (inventory_id, business_id) REFERENCES inventory(id, business_id),
    UNIQUE(business_id, source_id)
);

CREATE TABLE IF NOT EXISTS stock_transfers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    from_branch_id UUID NOT NULL,
    to_branch_id UUID NOT NULL,
    status TEXT DEFAULT 'PENDING',
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    source_id UUID,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    received_at TIMESTAMPTZ,
    CONSTRAINT fk_st_from_tenant FOREIGN KEY (from_branch_id, business_id) REFERENCES branches(id, business_id),
    CONSTRAINT fk_st_to_tenant FOREIGN KEY (to_branch_id, business_id) REFERENCES branches(id, business_id),
    CONSTRAINT different_branches CHECK (from_branch_id <> to_branch_id),
    UNIQUE(business_id, source_id)
);

CREATE TABLE IF NOT EXISTS stock_transfer_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    stock_transfer_id UUID NOT NULL,
    product_id UUID NOT NULL,
    quantity NUMERIC(15, 3) NOT NULL CHECK (quantity > 0),
    CONSTRAINT fk_sti_transfer_tenant FOREIGN KEY (stock_transfer_id, business_id) REFERENCES stock_transfers(id, business_id),
    CONSTRAINT fk_sti_product_tenant FOREIGN KEY (product_id, business_id) REFERENCES products(id, business_id)
);

-- -----------------------------------------------------------------------------
-- 009. CUSTOMERS
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS customers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    phone TEXT,
    email TEXT,
    customer_code TEXT,
    loyalty_points NUMERIC(15, 2) DEFAULT 0 CHECK (loyalty_points >= 0),
    is_active BOOLEAN DEFAULT TRUE,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    version INTEGER DEFAULT 1,
    source_id UUID,
    UNIQUE(id, business_id),
    UNIQUE(business_id, customer_code)
);

CREATE TABLE IF NOT EXISTS customer_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL,
    transaction_type TEXT NOT NULL,
    amount NUMERIC(19, 4) NOT NULL,
    balance_after NUMERIC(19, 4) NOT NULL,
    reference_id UUID,
    reference_type TEXT,
    transaction_date TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    source_id UUID,
    CONSTRAINT fk_cust_tx_tenant FOREIGN KEY (customer_id, business_id) REFERENCES customers(id, business_id),
    UNIQUE(business_id, source_id)
);

-- -----------------------------------------------------------------------------
-- 010. COMMERCE (SALES)
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS sales (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL,
    customer_id UUID,
    employee_id UUID NOT NULL,
    sale_number TEXT NOT NULL,
    receipt_number TEXT NOT NULL,
    sale_date TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status sale_status DEFAULT 'PENDING',
    total_amount NUMERIC(19, 4) NOT NULL DEFAULT 0 CHECK (total_amount >= 0),
    tax_total NUMERIC(19, 4) DEFAULT 0 CHECK (tax_total >= 0),
    discount_total NUMERIC(19, 4) DEFAULT 0 CHECK (discount_total >= 0),
    cost_total NUMERIC(19, 4) NOT NULL DEFAULT 0,
    paid_amount NUMERIC(19, 4) DEFAULT 0,
    source_id UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT fk_sale_branch_tenant FOREIGN KEY (branch_id, business_id) REFERENCES branches(id, business_id),
    CONSTRAINT fk_sale_customer_tenant FOREIGN KEY (customer_id, business_id) REFERENCES customers(id, business_id),
    CONSTRAINT fk_sale_employee_tenant FOREIGN KEY (employee_id, business_id) REFERENCES employees(id, business_id),
    UNIQUE(id, business_id),
    UNIQUE(business_id, sale_number),
    UNIQUE(branch_id, receipt_number), -- Scoped to branch
    UNIQUE(business_id, source_id)
);

CREATE TABLE IF NOT EXISTS sale_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    sale_id UUID NOT NULL,
    product_id UUID NOT NULL,
    variant_id UUID,
    quantity NUMERIC(15, 3) NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(19, 4) NOT NULL CHECK (unit_price >= 0),
    unit_cost_at_sale NUMERIC(19, 4) NOT NULL,
    total_price NUMERIC(19, 4) NOT NULL,
    CONSTRAINT fk_si_sale_tenant FOREIGN KEY (sale_id, business_id) REFERENCES sales(id, business_id),
    CONSTRAINT fk_si_product_tenant FOREIGN KEY (product_id, business_id) REFERENCES products(id, business_id),
    CONSTRAINT fk_si_variant_tenant FOREIGN KEY (variant_id, business_id) REFERENCES product_variants(id, business_id)
);

-- -----------------------------------------------------------------------------
-- 011. PAYMENTS
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS payment_methods (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    type payment_method_type NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    UNIQUE(id, business_id),
    UNIQUE(business_id, name)
);

CREATE TABLE IF NOT EXISTS payment_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    sale_id UUID,
    purchase_order_id UUID,
    payment_method_id UUID NOT NULL,
    amount NUMERIC(19, 4) NOT NULL CHECK (amount > 0),
    status payment_status DEFAULT 'CAPTURED',
    reference_number TEXT,
    source_id UUID,
    payment_date TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_pay_method_tenant FOREIGN KEY (payment_method_id, business_id) REFERENCES payment_methods(id, business_id),
    UNIQUE(business_id, source_id),
    CONSTRAINT sale_or_po_exclusive CHECK ((sale_id IS NOT NULL AND purchase_order_id IS NULL) OR (purchase_order_id IS NOT NULL AND sale_id IS NULL))
);

-- -----------------------------------------------------------------------------
-- 012. NOTIFICATIONS
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    branch_id UUID,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    severity severity_level DEFAULT 'LOW',
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_notify_branch_tenant FOREIGN KEY (branch_id, business_id) REFERENCES branches(id, business_id)
);

-- -----------------------------------------------------------------------------
-- 013. AUDIT & LOGGING
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_id UUID,
    action TEXT NOT NULL,
    entity_name TEXT NOT NULL,
    entity_id UUID NOT NULL,
    before_state JSONB,
    after_state JSONB,
    ip_address INET,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------------------------
-- 014. SYSTEM METADATA
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS migrations (
    id SERIAL PRIMARY KEY,
    version TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    applied_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------------------------
-- 015. DATABASE LOGIC (PROCEDURES)
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION trigger_update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ATOMIC SALE COMPLETION
CREATE OR REPLACE PROCEDURE proc_complete_sale(
    p_sale_id UUID,
    p_business_id UUID,
    p_user_id UUID
)
LANGUAGE plpgsql AS $$
DECLARE
    r_item RECORD;
    v_branch_id UUID;
    v_inv_id UUID;
    v_cur_qty NUMERIC;
    v_cur_status sale_status;
    v_total_paid NUMERIC;
    v_total_due NUMERIC;
BEGIN
    -- 1. Lock Sale and Validate
    SELECT branch_id, status, total_amount INTO v_branch_id, v_cur_status, v_total_due
    FROM sales
    WHERE id = p_sale_id AND business_id = p_business_id
    FOR UPDATE;

    IF v_cur_status = 'COMPLETED' THEN RETURN; END IF;

    -- Check payment coverage
    SELECT COALESCE(SUM(amount), 0) INTO v_total_paid
    FROM payment_transactions
    WHERE sale_id = p_sale_id AND status = 'CAPTURED';

    IF v_total_paid < v_total_due THEN
        RAISE EXCEPTION 'Insufficient payment for sale completion. Due: %, Paid: %', v_total_due, v_total_paid;
    END IF;

    -- 2. Atomic Stock Deduction
    FOR r_item IN SELECT product_id, quantity, unit_cost_at_sale FROM sale_items WHERE sale_id = p_sale_id LOOP
        SELECT id, quantity INTO v_inv_id, v_cur_qty
        FROM inventory
        WHERE branch_id = v_branch_id AND product_id = r_item.product_id
        FOR UPDATE;

        IF v_inv_id IS NULL OR v_cur_qty < r_item.quantity THEN
            RAISE EXCEPTION 'Insufficient stock for product ID % in branch %', r_item.product_id, v_branch_id;
        END IF;

        UPDATE inventory SET quantity = quantity - r_item.quantity WHERE id = v_inv_id;

        INSERT INTO inventory_transactions (
            business_id, branch_id, inventory_id, product_id,
            transaction_type, reference_id, reference_type,
            previous_quantity, quantity_change, resulting_quantity,
            unit_cost, user_id
        ) VALUES (
            p_business_id, v_branch_id, v_inv_id, r_item.product_id,
            'SALE', p_sale_id, 'SALE',
            v_cur_qty, -r_item.quantity, v_cur_qty - r_item.quantity,
            r_item.unit_cost_at_sale, p_user_id
        );
    END LOOP;

    -- 3. Finalize
    UPDATE sales SET status = 'COMPLETED', paid_amount = v_total_paid, updated_at = CURRENT_TIMESTAMP WHERE id = p_sale_id;
END;
$$;

-- ATOMIC PURCHASE RECEIVING (Partial Supported)
CREATE OR REPLACE PROCEDURE proc_receive_purchase(
    p_po_id UUID,
    p_business_id UUID,
    p_received_items JSONB, -- [{product_id, quantity}]
    p_user_id UUID
)
LANGUAGE plpgsql AS $$
DECLARE
    v_branch_id UUID;
    v_item JSONB;
    v_landed_cost NUMERIC;
    v_inv_id UUID;
    v_old_qty NUMERIC;
    v_old_wac NUMERIC;
    v_received_qty NUMERIC;
    v_prod_id UUID;
BEGIN
    SELECT branch_id INTO v_branch_id FROM purchase_orders WHERE id = p_po_id AND business_id = p_business_id FOR UPDATE;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_received_items) LOOP
        v_prod_id := (v_item->>'product_id')::uuid;
        v_received_qty := (v_item->>'quantity')::numeric;

        IF v_received_qty <= 0 THEN CONTINUE; END IF;

        -- Validate PO Item & Landed Cost
        SELECT landed_unit_cost INTO v_landed_cost
        FROM purchase_order_items
        WHERE purchase_order_id = p_po_id AND product_id = v_prod_id;

        -- Lock Inventory
        INSERT INTO inventory (business_id, branch_id, product_id, quantity, weighted_average_cost)
        VALUES (p_business_id, v_branch_id, v_prod_id, 0, 0)
        ON CONFLICT (branch_id, product_id) DO NOTHING;

        SELECT id, quantity, weighted_average_cost INTO v_inv_id, v_old_qty, v_old_wac
        FROM inventory WHERE branch_id = v_branch_id AND product_id = v_prod_id FOR UPDATE;

        -- WAC Update
        IF (v_old_qty + v_received_qty) > 0 THEN
            UPDATE inventory SET
                weighted_average_cost = ((v_old_qty * v_old_wac) + (v_received_qty * v_landed_cost)) / (v_old_qty + v_received_qty),
                quantity = v_old_qty + v_received_qty,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = v_inv_id;
        END IF;

        -- Record Item Received
        UPDATE purchase_order_items
        SET received_quantity = received_quantity + v_received_qty
        WHERE purchase_order_id = p_po_id AND product_id = v_prod_id;

        -- Log Transaction
        INSERT INTO inventory_transactions (
            business_id, branch_id, inventory_id, product_id,
            transaction_type, reference_id, reference_type,
            previous_quantity, quantity_change, resulting_quantity,
            unit_cost, user_id
        ) VALUES (
            p_business_id, v_branch_id, v_inv_id, v_prod_id,
            'PURCHASE', p_po_id, 'PURCHASE_ORDER',
            v_old_qty, v_received_qty, v_old_qty + v_received_qty,
            v_landed_cost, p_user_id
        );
    END LOOP;

    -- Update status
    UPDATE purchase_orders SET
        status = CASE
            WHEN NOT EXISTS (SELECT 1 FROM purchase_order_items WHERE purchase_order_id = p_po_id AND received_quantity < quantity) THEN 'RECEIVED'::purchase_status
            ELSE 'PARTIAL'::purchase_status
        END
    WHERE id = p_po_id;
END;
$$;

-- -----------------------------------------------------------------------------
-- 016. ROW LEVEL SECURITY (Isolation)
-- -----------------------------------------------------------------------------

DO $$
DECLARE
    t TEXT;
BEGIN
    FOR t IN SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'
    AND table_name NOT IN ('migrations', 'users', 'permissions', 'role_permissions') LOOP
        -- Check if the table has a business_id column before enabling RLS
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = t AND column_name = 'business_id') THEN
            EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
            EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY', t);
            EXECUTE format('DROP POLICY IF EXISTS tenant_policy ON %I', t);

            -- Policy uses a session variable for business isolation
            EXECUTE format('CREATE POLICY tenant_policy ON %I FOR ALL
                USING (business_id = coalesce(current_setting(''app.current_business_id'', true), ''00000000-0000-0000-0000-000000000000'')::uuid)
                WITH CHECK (business_id = coalesce(current_setting(''app.current_business_id'', true), ''00000000-0000-0000-0000-000000000000'')::uuid)', t, t);
        END IF;
    END LOOP;
END $$;

-- -----------------------------------------------------------------------------
-- 017. INDEXING
-- -----------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_products_sku ON products(business_id, sku);
CREATE INDEX IF NOT EXISTS idx_barcodes_val ON product_barcodes(business_id, barcode);
CREATE INDEX IF NOT EXISTS idx_inventory_lookup ON inventory(branch_id, product_id);
CREATE INDEX IF NOT EXISTS idx_sales_date ON sales(business_id, sale_date DESC);
CREATE INDEX IF NOT EXISTS idx_sales_receipt ON sales(branch_id, receipt_number);
CREATE INDEX IF NOT EXISTS idx_sync_source ON sales(business_id, source_id);

-- -----------------------------------------------------------------------------
-- 018. SEED DATA
-- -----------------------------------------------------------------------------

INSERT INTO permissions (slug, name, module) VALUES
('view_dashboard', 'View Dashboard', 'Analytics'),
('manage_inventory', 'Manage Inventory', 'Inventory'),
('create_sale', 'Point of Sale', 'Sales'),
('manage_purchases', 'Manage Procurement', 'Purchases'),
('manage_staff', 'Manage Employees', 'HR'),
('manage_settings', 'System Settings', 'Admin')
ON CONFLICT (slug) DO NOTHING;

COMMIT;
