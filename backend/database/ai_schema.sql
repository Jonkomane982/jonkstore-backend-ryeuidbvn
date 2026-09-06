-- JONK AI DATA FOUNDATION - PostgreSQL Schema
-- Optimized for Analytical Processing (OLAP) and Future AI Vector Search

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. AI METADATA & AUDIT
CREATE TABLE IF NOT EXISTS ai_data_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entity_name TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    operation TEXT NOT NULL, -- CREATE, UPDATE, DELETE
    sync_timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    processing_status TEXT DEFAULT 'PENDING' -- PENDING, PROCESSED, FAILED
);

-- 2. CORE ANALYTICAL TABLES (Mirrored from POS)
-- Business Context
CREATE TABLE IF NOT EXISTS ai_businesses (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    industry TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    metadata JSONB -- Flexible store for AI-specific attributes
);

-- Product Dimension
CREATE TABLE IF NOT EXISTS ai_products (
    id TEXT PRIMARY KEY,
    business_id TEXT REFERENCES ai_businesses(id),
    name TEXT NOT NULL,
    category_id TEXT,
    buying_price NUMERIC(15,2),
    selling_price NUMERIC(15,2),
    sku TEXT,
    is_active BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE
);

-- Inventory Snapshots (For Forecasting)
CREATE TABLE IF NOT EXISTS ai_inventory_snapshots (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id TEXT REFERENCES ai_products(id),
    branch_id TEXT,
    quantity NUMERIC(15,2),
    snapshot_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Sales Fact Table (Primary AI Data Source)
CREATE TABLE IF NOT EXISTS ai_sales (
    id TEXT PRIMARY KEY,
    business_id TEXT REFERENCES ai_businesses(id),
    branch_id TEXT,
    customer_id TEXT,
    total_amount NUMERIC(15,2),
    tax_amount NUMERIC(15,2),
    discount_amount NUMERIC(15,2),
    payment_method TEXT,
    sale_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS ai_sale_items (
    id TEXT PRIMARY KEY,
    sale_id TEXT REFERENCES ai_sales(id) ON DELETE CASCADE,
    product_id TEXT REFERENCES ai_products(id),
    quantity NUMERIC(15,2),
    unit_price NUMERIC(15,2),
    total_price NUMERIC(15,2)
);

-- 3. AI INDEXES FOR PERFORMANCE
CREATE INDEX IF NOT EXISTS idx_ai_sales_date ON ai_sales(sale_date);
CREATE INDEX IF NOT EXISTS idx_ai_inventory_product ON ai_inventory_snapshots(product_id, snapshot_date);
