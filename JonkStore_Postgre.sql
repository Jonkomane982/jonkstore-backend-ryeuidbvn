-- ============================================================================
-- JONKSTORE POS - PRIMARY OPERATIONAL POSTGRESQL DATABASE SCHEMA
-- Version: 5.3.0 (Full Cleanup, Hardened & Performance Optimized)
-- ============================================================================

/*
ARCHITECTURAL DESIGN PRINCIPLES:
1. TENANT ISOLATION: Enforced via business_id columns and hardened RLS.
2. FINANCIAL INTEGRITY: NUMERIC(19,4) for all monetary fields.
3. ATOMICITY: Procedures for Sale Completion and Purchase Receiving ensure consistency.
4. OFFLINE-FIRST: source_id (UUID) tracking for idempotent synchronization.
*/

-- -----------------------------------------------------------------------------
-- 000. CLEANUP (Drops existing tables to ensure a fresh start)
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS expenses CASCADE;
DROP TABLE IF EXISTS expense_categories CASCADE;
DROP TABLE IF EXISTS payment_transactions CASCADE;
DROP TABLE IF EXISTS sale_items CASCADE;
DROP TABLE IF EXISTS sales CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS purchase_order_items CASCADE;
DROP TABLE IF EXISTS purchase_orders CASCADE;
DROP TABLE IF EXISTS inventory_transactions CASCADE;
DROP TABLE IF EXISTS inventory CASCADE;
DROP TABLE IF EXISTS product_suppliers CASCADE;
DROP TABLE IF EXISTS suppliers CASCADE;
DROP TABLE IF EXISTS product_barcodes CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS categories CASCADE;
DROP TABLE IF EXISTS otps CASCADE;
DROP TABLE IF EXISTS employees CASCADE;
DROP TABLE IF EXISTS owner_profiles CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS taxes CASCADE;
DROP TABLE IF EXISTS currencies CASCADE;
DROP TABLE IF EXISTS branches CASCADE;
DROP TABLE IF EXISTS businesses CASCADE;

DROP TYPE IF EXISTS sync_status_type CASCADE;
DROP TYPE IF EXISTS product_type CASCADE;
DROP TYPE IF EXISTS purchase_status CASCADE;
DROP TYPE IF EXISTS sale_status CASCADE;
DROP TYPE IF EXISTS inventory_transaction_type CASCADE;
DROP TYPE IF EXISTS runner_fee_allocation_method CASCADE;
DROP TYPE IF EXISTS payment_method_type CASCADE;
DROP TYPE IF EXISTS payment_status CASCADE;
DROP TYPE IF EXISTS severity_level CASCADE;

BEGIN;

-- -----------------------------------------------------------------------------
-- 001. EXTENSIONS
-- -----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gist";

-- -----------------------------------------------------------------------------
-- 002. TYPES AND ENUMERATIONS
-- -----------------------------------------------------------------------------
CREATE TYPE sync_status_type AS ENUM ('PENDING', 'SYNCED', 'CONFLICT', 'FAILED');
CREATE TYPE product_type AS ENUM ('PHYSICAL', 'SERVICE', 'DIGITAL');
CREATE TYPE purchase_status AS ENUM ('DRAFT', 'PENDING', 'PARTIAL', 'RECEIVED', 'CANCELLED');
CREATE TYPE sale_status AS ENUM ('DRAFT', 'PENDING', 'COMPLETED', 'CANCELLED', 'RETURNED', 'PARTIALLY_RETURNED');
CREATE TYPE inventory_transaction_type AS ENUM ('PURCHASE', 'SALE', 'RETURN_CUSTOMER', 'RETURN_SUPPLIER', 'DAMAGE', 'ADJUSTMENT', 'STOCK_COUNT', 'TRANSFER_IN', 'TRANSFER_OUT');
CREATE TYPE runner_fee_allocation_method AS ENUM ('PROPORTIONAL_BY_COST', 'EQUAL');
CREATE TYPE payment_method_type AS ENUM ('CASH', 'CARD', 'MOBILE_MONEY', 'BANK_TRANSFER', 'OTHER');
CREATE TYPE payment_status AS ENUM ('PENDING', 'AUTHORIZED', 'CAPTURED', 'REFUNDED', 'FAILED', 'REVERSED');
CREATE TYPE severity_level AS ENUM ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL');

-- -----------------------------------------------------------------------------
-- 003. CORE INFRASTRUCTURE
-- -----------------------------------------------------------------------------

CREATE TABLE businesses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    tax_id TEXT,
    industry TEXT,
    logo_url TEXT,
    website TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    source_id UUID
);

CREATE TABLE branches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    code TEXT,
    address TEXT,
    phone TEXT,
    is_main_branch BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    UNIQUE(id, business_id)
);

CREATE TABLE currencies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    code VARCHAR(3) NOT NULL,
    symbol VARCHAR(5) NOT NULL,
    name TEXT NOT NULL,
    exchange_rate NUMERIC(19, 6) DEFAULT 1.0,
    UNIQUE(business_id, code),
    UNIQUE(id, business_id)
);

CREATE TABLE taxes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    rate NUMERIC(7, 6) NOT NULL CHECK (rate >= 0 AND rate <= 1.0),
    is_compound BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(id, business_id)
);

-- -----------------------------------------------------------------------------
-- 004. IDENTITY & SECURITY
-- -----------------------------------------------------------------------------

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    firebase_uid TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE NOT NULL,
    username TEXT UNIQUE,
    role_name TEXT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE owner_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    phone TEXT,
    UNIQUE(user_id, business_id)
);

CREATE TABLE employees (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    user_id UUID UNIQUE REFERENCES users(id) ON DELETE SET NULL,
    branch_id UUID NOT NULL,
    employee_code TEXT NOT NULL,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    CONSTRAINT fk_employee_branch_tenant FOREIGN KEY (branch_id, business_id) REFERENCES branches(id, business_id),
    UNIQUE(business_id, employee_code)
);

CREATE TABLE otps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL,
    otp_code TEXT NOT NULL,
    purpose TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    verified_at TIMESTAMPTZ,
    is_used BOOLEAN DEFAULT FALSE
);

-- -----------------------------------------------------------------------------
-- 005. CATALOG (PRODUCTS & SUPPLIERS)
-- -----------------------------------------------------------------------------

CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    parent_id UUID,
    CONSTRAINT fk_category_parent_tenant FOREIGN KEY (parent_id, business_id) REFERENCES categories(id, business_id),
    UNIQUE(id, business_id)
);

CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    category_id UUID NOT NULL,
    name TEXT NOT NULL,
    sku TEXT NOT NULL,
    description TEXT,
    selling_price NUMERIC(19, 4) NOT NULL DEFAULT 0,
    track_inventory BOOLEAN DEFAULT TRUE,
    is_active BOOLEAN DEFAULT TRUE,
    source_id UUID,
    CONSTRAINT fk_product_category_tenant FOREIGN KEY (category_id, business_id) REFERENCES categories(id, business_id),
    UNIQUE(id, business_id),
    UNIQUE(business_id, sku)
);

CREATE TABLE product_barcodes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    product_id UUID NOT NULL,
    barcode TEXT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    CONSTRAINT fk_barcode_product_tenant FOREIGN KEY (product_id, business_id) REFERENCES products(id, business_id),
    UNIQUE(business_id, barcode)
);

CREATE TABLE suppliers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    supplier_code TEXT NOT NULL,
    contact_name TEXT,
    email TEXT,
    phone TEXT,
    UNIQUE(id, business_id),
    UNIQUE(business_id, supplier_code)
);

CREATE TABLE product_suppliers (
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id),
    supplier_id UUID NOT NULL REFERENCES suppliers(id),
    buying_cost NUMERIC(19, 4) NOT NULL DEFAULT 0,
    CONSTRAINT fk_ps_product_tenant FOREIGN KEY (product_id, business_id) REFERENCES products(id, business_id),
    CONSTRAINT fk_ps_supplier_tenant FOREIGN KEY (supplier_id, business_id) REFERENCES suppliers(id, business_id),
    PRIMARY KEY (product_id, supplier_id)
);

-- -----------------------------------------------------------------------------
-- 006. FULFILLMENT (INVENTORY)
-- -----------------------------------------------------------------------------

CREATE TABLE inventory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL,
    product_id UUID NOT NULL,
    quantity NUMERIC(15, 3) NOT NULL DEFAULT 0,
    weighted_average_cost NUMERIC(19, 4) DEFAULT 0 CHECK (weighted_average_cost >= 0),
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_inv_branch_tenant FOREIGN KEY (branch_id, business_id) REFERENCES branches(id, business_id),
    CONSTRAINT fk_inv_product_tenant FOREIGN KEY (product_id, business_id) REFERENCES products(id, business_id),
    UNIQUE(branch_id, product_id),
    UNIQUE(id, business_id)
);

CREATE TABLE inventory_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL,
    inventory_id UUID NOT NULL REFERENCES inventory(id),
    product_id UUID NOT NULL,
    transaction_type inventory_transaction_type NOT NULL,
    reference_id UUID NOT NULL,
    reference_type TEXT NOT NULL,
    quantity_change NUMERIC(15, 3) NOT NULL,
    resulting_quantity NUMERIC(15, 3) NOT NULL,
    unit_cost NUMERIC(19, 4),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    source_id UUID,
    CONSTRAINT fk_it_inv_tenant FOREIGN KEY (inventory_id, business_id) REFERENCES inventory(id, business_id),
    UNIQUE(business_id, source_id)
);

-- -----------------------------------------------------------------------------
-- 007. PROCUREMENT (PURCHASES)
-- -----------------------------------------------------------------------------

CREATE TABLE purchase_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL REFERENCES branches(id),
    supplier_id UUID NOT NULL REFERENCES suppliers(id),
    order_number TEXT NOT NULL,
    total_amount NUMERIC(19, 4) NOT NULL DEFAULT 0,
    status purchase_status DEFAULT 'PENDING',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(business_id, order_number),
    UNIQUE(id, business_id)
);

CREATE TABLE purchase_order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    purchase_order_id UUID NOT NULL,
    product_id UUID NOT NULL,
    quantity NUMERIC(15, 3) NOT NULL,
    received_quantity NUMERIC(15, 3) DEFAULT 0,
    unit_buying_price NUMERIC(19, 4) NOT NULL,
    landed_unit_cost NUMERIC(19, 4) NOT NULL,
    CONSTRAINT fk_poi_order_tenant FOREIGN KEY (purchase_order_id, business_id) REFERENCES purchase_orders(id, business_id),
    CONSTRAINT fk_poi_product_tenant FOREIGN KEY (product_id, business_id) REFERENCES products(id, business_id)
);

-- -----------------------------------------------------------------------------
-- 008. COMMERCE (SALES)
-- -----------------------------------------------------------------------------

CREATE TABLE customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    phone TEXT,
    email TEXT,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(id, business_id)
);

CREATE TABLE sales (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL,
    customer_id UUID REFERENCES customers(id),
    employee_id UUID NOT NULL REFERENCES employees(id),
    sale_number TEXT NOT NULL,
    receipt_number TEXT NOT NULL,
    total_amount NUMERIC(19, 4) NOT NULL DEFAULT 0,
    cost_total NUMERIC(19, 4) NOT NULL DEFAULT 0,
    paid_amount NUMERIC(19, 4) DEFAULT 0,
    status sale_status DEFAULT 'PENDING',
    sale_date TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    source_id UUID,
    CONSTRAINT fk_sale_branch_tenant FOREIGN KEY (branch_id, business_id) REFERENCES branches(id, business_id),
    UNIQUE(id, business_id),
    UNIQUE(business_id, sale_number),
    UNIQUE(branch_id, receipt_number)
);

CREATE TABLE sale_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    sale_id UUID NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
    product_id UUID NOT NULL,
    quantity NUMERIC(15, 3) NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(19, 4) NOT NULL CHECK (unit_price >= 0),
    unit_cost_at_sale NUMERIC(19, 4) NOT NULL,
    total_price NUMERIC(19, 4) NOT NULL,
    CONSTRAINT fk_si_sale_tenant FOREIGN KEY (sale_id, business_id) REFERENCES sales(id, business_id),
    CONSTRAINT fk_si_product_tenant FOREIGN KEY (product_id, business_id) REFERENCES products(id, business_id)
);

CREATE TABLE payment_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    sale_id UUID REFERENCES sales(id) ON DELETE CASCADE,
    amount NUMERIC(19, 4) NOT NULL CHECK (amount > 0),
    status payment_status DEFAULT 'CAPTURED',
    source_id UUID,
    UNIQUE(business_id, source_id)
);

-- -----------------------------------------------------------------------------
-- 009. EXPENSES
-- -----------------------------------------------------------------------------

CREATE TABLE expense_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    UNIQUE(business_id, name)
);

CREATE TABLE expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL REFERENCES branches(id),
    category_id UUID NOT NULL REFERENCES expense_categories(id),
    amount NUMERIC(19, 4) NOT NULL,
    description TEXT,
    expense_date TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------------------------
-- 010. RLS IMPLEMENTATION (Hardened)
-- -----------------------------------------------------------------------------

DO $$
DECLARE
    t TEXT;
BEGIN
    FOR t IN SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'
    AND table_name NOT IN ('migrations', 'users', 'permissions', 'role_permissions', 'otps', 'businesses') LOOP
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = t AND column_name = 'business_id') THEN
            EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
            EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY', t);
            EXECUTE format('DROP POLICY IF EXISTS tenant_policy ON %I', t);

            EXECUTE format('CREATE POLICY tenant_policy ON %I FOR ALL
                USING (business_id = coalesce(current_setting(''app.current_business_id'', true), ''00000000-0000-0000-0000-000000000000'')::uuid)
                WITH CHECK (business_id = coalesce(current_setting(''app.current_business_id'', true), ''00000000-0000-0000-0000-000000000000'')::uuid)', t, t);
        END IF;
    END LOOP;
END $$;

-- -----------------------------------------------------------------------------
-- 011. PROCEDURES
-- -----------------------------------------------------------------------------

-- Finalize a Sale
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
    v_total_paid NUMERIC;
    v_total_due NUMERIC;
    v_cur_status sale_status;
BEGIN
    SELECT branch_id, status, total_amount INTO v_branch_id, v_cur_status, v_total_due
    FROM sales WHERE id = p_sale_id AND business_id = p_business_id FOR UPDATE;

    IF v_cur_status = 'COMPLETED' THEN
        RETURN;
    END IF;

    SELECT COALESCE(SUM(amount), 0) INTO v_total_paid
    FROM payment_transactions WHERE sale_id = p_sale_id AND status = 'CAPTURED';

    IF v_total_paid < v_total_due THEN
        RAISE EXCEPTION 'Insufficient payment';
    END IF;

    FOR r_item IN SELECT product_id, quantity, unit_cost_at_sale FROM sale_items WHERE sale_id = p_sale_id LOOP
        SELECT id, quantity INTO v_inv_id, v_cur_qty
        FROM inventory WHERE branch_id = v_branch_id AND product_id = r_item.product_id FOR UPDATE;

        IF v_inv_id IS NULL OR v_cur_qty < r_item.quantity THEN
            RAISE EXCEPTION 'Insufficient stock for product %', r_item.product_id;
        END IF;

        UPDATE inventory SET quantity = quantity - r_item.quantity WHERE id = v_inv_id;

        INSERT INTO inventory_transactions (
            business_id, branch_id, inventory_id, product_id,
            transaction_type, reference_id, reference_type,
            quantity_change, resulting_quantity, unit_cost
        ) VALUES (
            p_business_id, v_branch_id, v_inv_id, r_item.product_id,
            'SALE', p_sale_id, 'SALE',
            -r_item.quantity, v_cur_qty - r_item.quantity, r_item.unit_cost_at_sale
        );
    END LOOP;

    UPDATE sales SET status = 'COMPLETED', paid_amount = v_total_paid, updated_at = CURRENT_TIMESTAMP WHERE id = p_sale_id;
END;
$$;

-- Receive Purchase
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

        SELECT landed_unit_cost INTO v_landed_cost FROM purchase_order_items WHERE purchase_order_id = p_po_id AND product_id = v_prod_id;

        INSERT INTO inventory (business_id, branch_id, product_id, quantity, weighted_average_cost)
        VALUES (p_business_id, v_branch_id, v_prod_id, 0, 0)
        ON CONFLICT (branch_id, product_id) DO NOTHING;

        SELECT id, quantity, weighted_average_cost INTO v_inv_id, v_old_qty, v_old_wac
        FROM inventory WHERE branch_id = v_branch_id AND product_id = v_prod_id FOR UPDATE;

        IF (v_old_qty + v_received_qty) > 0 THEN
            UPDATE inventory SET
                weighted_average_cost = ((v_old_qty * v_old_wac) + (v_received_qty * v_landed_cost)) / (v_old_qty + v_received_qty),
                quantity = v_old_qty + v_received_qty,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = v_inv_id;
        END IF;

        UPDATE purchase_order_items SET received_quantity = received_quantity + v_received_qty
        WHERE purchase_order_id = p_po_id AND product_id = v_prod_id;

        INSERT INTO inventory_transactions (business_id, branch_id, inventory_id, product_id, transaction_type, reference_id, reference_type, quantity_change, resulting_quantity, unit_cost)
        VALUES (p_business_id, v_branch_id, v_inv_id, v_prod_id, 'PURCHASE', p_po_id, 'PURCHASE_ORDER', v_received_qty, v_old_qty + v_received_qty, v_landed_cost);
    END LOOP;
END;
$$;

-- -----------------------------------------------------------------------------
-- 012. PERFORMANCE OPTIMIZATIONS (TRIGGERS, VIEWS, INDEXES)
-- -----------------------------------------------------------------------------

-- 1. Automatic update of updated_at column
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_businesses_updated_at BEFORE UPDATE ON businesses FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_update_inventory_updated_at BEFORE UPDATE ON inventory FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_update_sales_updated_at BEFORE UPDATE ON sales FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_update_customers_updated_at BEFORE UPDATE ON customers FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 2. Performance Indexes (Adding optimized indexes for fast lookups)

-- Date-based lookups for reporting
CREATE INDEX IF NOT EXISTS idx_sales_date ON sales(business_id, sale_date);
CREATE INDEX IF NOT EXISTS idx_inventory_transactions_created ON inventory_transactions(business_id, created_at);
CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(business_id, expense_date);

-- Relationship lookups (Foreign Keys)
CREATE INDEX IF NOT EXISTS idx_products_category ON products(business_id, category_id);
CREATE INDEX IF NOT EXISTS idx_sales_customer_id ON sales(business_id, customer_id);
CREATE INDEX IF NOT EXISTS idx_sales_employee_id ON sales(business_id, employee_id);
CREATE INDEX IF NOT EXISTS idx_sale_items_sale_id ON sale_items(sale_id);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_supplier_id ON purchase_orders(business_id, supplier_id);
CREATE INDEX IF NOT EXISTS idx_purchase_order_items_po_id ON purchase_order_items(purchase_order_id);
CREATE INDEX IF NOT EXISTS idx_inventory_transactions_inventory_id ON inventory_transactions(inventory_id);

-- Customer lookups
CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(business_id, phone);
CREATE INDEX IF NOT EXISTS idx_customers_email ON customers(business_id, email);

-- Full-text/Trigram search optimization for product names and SKUs
CREATE INDEX IF NOT EXISTS idx_products_name_trgm ON products USING GIN (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_products_sku_trgm ON products USING GIN (sku gin_trgm_ops);

-- 3. Optimization Views
CREATE OR REPLACE VIEW vw_inventory_summary AS
SELECT
    p.business_id,
    p.id AS product_id,
    p.name AS product_name,
    p.sku,
    c.name AS category_name,
    i.branch_id,
    b.name AS branch_name,
    i.quantity,
    i.weighted_average_cost,
    (i.quantity * i.weighted_average_cost) AS total_inventory_value
FROM products p
JOIN categories c ON p.category_id = c.id
JOIN inventory i ON p.id = i.product_id
JOIN branches b ON i.branch_id = b.id
WHERE p.is_active = TRUE;

CREATE OR REPLACE VIEW vw_daily_sales_summary AS
SELECT
    business_id,
    branch_id,
    DATE(sale_date) AS sale_day,
    COUNT(id) AS total_sales_count,
    SUM(total_amount) AS total_sales_amount,
    SUM(cost_total) AS total_cost_amount,
    SUM(total_amount - cost_total) AS total_profit
FROM sales
WHERE status = 'COMPLETED'
GROUP BY business_id, branch_id, DATE(sale_date);

COMMIT;
