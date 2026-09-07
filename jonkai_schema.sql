-- ============================================================================
-- JONKAI POSTGRESQL DATABASE SCHEMA — FINAL PRODUCTION RELEASE
-- Version: 3.2.0 (Hardened, Prolog-Ready & AI-Enhanced)
-- Principal AI Database Architect & Data Engineer
-- ============================================================================

/*
ARCHITECTURAL PILLARS:
1. DECOUPLING: Physically separate from the JonkStore POS Operational Database.
2. LINEAGE: Every analytical row is traceable to its source system, record ID, and version.
3. IDEMPOTENCY: Ingestion logic prevents duplicate record creation during pipeline retries.
4. MULTI-TENANCY: Structural isolation via business_id and Row-Level Security (RLS).
5. REASONING READY: Logical structure designed for Prolog predicate extraction.
6. ANALYTICALLY OPTIMIZED: Star-schema (Facts/Dimensions) for high-speed forecasting.
7. CONVERSATIONAL MEMORY: Stores grounded LLM interactions and tool-calling logs.
*/

BEGIN;

-- -----------------------------------------------------------------------------
-- 001. EXTENSIONS
-- -----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gist";

-- -----------------------------------------------------------------------------
-- 002. LOGICAL LAYERS (SCHEMAS)
-- -----------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS jonkai_ingest;    -- 1. INGESTION: Landing & Pipeline Status
CREATE SCHEMA IF NOT EXISTS jonkai_raw;       -- 2. RAW EVENTS: General Event Foundation
CREATE SCHEMA IF NOT EXISTS jonkai_core;      -- 3. NORMALIZED CORE: AI Operational Mirror
CREATE SCHEMA IF NOT EXISTS jonkai_analytics; -- 4,5. ANALYTICAL FACTS & DIMENSIONS
CREATE SCHEMA IF NOT EXISTS jonkai_metrics;   -- 6. METRICS: Derived KPI Snapshots
CREATE SCHEMA IF NOT EXISTS jonkai_features;  -- 7. FEATURES: ML Feature Store (Python)
CREATE SCHEMA IF NOT EXISTS jonkai_knowledge; -- 8. KNOWLEDGE: Domain info & Patterns
CREATE SCHEMA IF NOT EXISTS jonkai_rules;     -- 9. BUSINESS RULES: Prolog Logic base
CREATE SCHEMA IF NOT EXISTS jonkai_memory;    -- 10. MEMORY: Business/User preferences
CREATE SCHEMA IF NOT EXISTS jonkai_security;  -- 11. SECURITY ANALYTICS: Observed behavior
CREATE SCHEMA IF NOT EXISTS jonkai_ai;        -- 12,13. AI OUTPUTS & MODEL RUNS
CREATE SCHEMA IF NOT EXISTS jonkai_chat;      -- 14. CONVERSATIONS: LLM Context (OpenAI)
CREATE SCHEMA IF NOT EXISTS jonkai_audit;     -- 15. AUDIT / LINEAGE: Traceability Logs
CREATE SCHEMA IF NOT EXISTS jonkai_gateway;   -- AI DATA GATEWAY: Controlled Access

-- -----------------------------------------------------------------------------
-- 003. TYPES & ENUMERATIONS
-- -----------------------------------------------------------------------------
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'processing_status' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'jonkai_ingest')) THEN
        CREATE TYPE jonkai_ingest.processing_status AS ENUM ('RECEIVED', 'VALIDATED', 'ACCEPTED', 'PROCESSED', 'REJECTED', 'FAILED', 'RETRYING');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'event_source' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'jonkai_raw')) THEN
        CREATE TYPE jonkai_raw.event_source AS ENUM ('POS_POSTGRES', 'FIRESTORE', 'SQLITE_SYNC', 'BACKEND_EVENT', 'MANUAL');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'knowledge_kind' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'jonkai_knowledge')) THEN
        CREATE TYPE jonkai_knowledge.knowledge_kind AS ENUM ('GENERAL', 'BUSINESS', 'USER_PROVIDED', 'SYSTEM', 'APPROVED_RULE', 'LEARNED_PATTERN');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'approval_status' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'jonkai_knowledge')) THEN
        CREATE TYPE jonkai_knowledge.approval_status AS ENUM ('DRAFT', 'PENDING', 'APPROVED', 'REJECTED', 'DEPRECATED', 'ARCHIVED');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'recommendation_priority' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'jonkai_ai')) THEN
        CREATE TYPE jonkai_ai.recommendation_priority AS ENUM ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'artifact_status' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'jonkai_ai')) THEN
        CREATE TYPE jonkai_ai.artifact_status AS ENUM ('ACTIVE', 'APPLIED', 'DISMISSED', 'EXPIRED', 'FAILED');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'feedback_val' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'jonkai_ai')) THEN
        CREATE TYPE jonkai_ai.feedback_val AS ENUM ('HELPFUL', 'NOT_HELPFUL', 'CORRECT', 'INCORRECT', 'DISMISSED', 'APPLIED');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'time_granularity' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'jonkai_analytics')) THEN
        CREATE TYPE jonkai_analytics.time_granularity AS ENUM ('HOUR', 'DAY', 'WEEK', 'MONTH', 'QUARTER', 'YEAR');
    END IF;
END $$;

-- -----------------------------------------------------------------------------
-- 004. LAYER 1: INGESTION (jonkai_ingest)
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS jonkai_ingest.payloads (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_system jonkai_raw.event_source NOT NULL,
    source_record_id TEXT NOT NULL,       -- Primary Key in the source system
    source_version INTEGER DEFAULT 1,     -- Version of the entity at event time
    business_id UUID NOT NULL,
    event_type TEXT NOT NULL,             -- 'SaleCompleted', 'ProductUpdated'
    payload JSONB NOT NULL,
    payload_hash TEXT NOT NULL,           -- SHA-256 for dedup
    idempotency_key TEXT,
    received_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    status jonkai_ingest.processing_status DEFAULT 'RECEIVED',
    processed_at TIMESTAMPTZ,
    error_message TEXT,
    attempt_count INTEGER DEFAULT 0,

    -- LINEAGE PROTECTION: Prevent re-processing same version of entity version from same system
    UNIQUE(source_system, source_record_id, source_version, event_type)
);

-- -----------------------------------------------------------------------------
-- 005. LAYER 3: NORMALIZED CORE (jonkai_core) - Historical Mirror
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS jonkai_core.businesses (
    business_id UUID PRIMARY KEY,
    name TEXT NOT NULL,
    industry TEXT,
    source_version INTEGER NOT NULL,
    ingested_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    payload JSONB
);

CREATE TABLE IF NOT EXISTS jonkai_core.branches (
    branch_id UUID PRIMARY KEY,
    business_id UUID NOT NULL,
    name TEXT NOT NULL,
    code TEXT,
    source_version INTEGER NOT NULL,
    ingested_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS jonkai_core.products (
    product_id UUID PRIMARY KEY,
    business_id UUID NOT NULL,
    category_id UUID,
    name TEXT NOT NULL,
    sku TEXT,
    selling_price NUMERIC(19, 4),
    source_version INTEGER NOT NULL,
    ingested_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS jonkai_core.product_barcodes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL,
    product_id UUID NOT NULL REFERENCES jonkai_core.products(product_id),
    barcode TEXT NOT NULL,
    type TEXT,
    source_version INTEGER NOT NULL,
    ingested_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS jonkai_core.sales (
    sale_id UUID PRIMARY KEY,
    business_id UUID NOT NULL,
    branch_id UUID NOT NULL,
    customer_id UUID,
    employee_id UUID,
    total_amount NUMERIC(19, 4) NOT NULL,
    sale_date TIMESTAMPTZ NOT NULL,
    source_version INTEGER NOT NULL,
    ingested_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    status TEXT
);

CREATE TABLE IF NOT EXISTS jonkai_core.sale_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sale_id UUID NOT NULL REFERENCES jonkai_core.sales(sale_id),
    business_id UUID NOT NULL,
    product_id UUID NOT NULL,
    quantity NUMERIC(15, 3) NOT NULL,
    unit_price NUMERIC(19, 4) NOT NULL,
    unit_cost_at_sale NUMERIC(19, 4)
);

CREATE TABLE IF NOT EXISTS jonkai_core.inventory (
    inventory_id UUID PRIMARY KEY,
    business_id UUID NOT NULL,
    branch_id UUID NOT NULL,
    product_id UUID NOT NULL,
    quantity NUMERIC(15, 3) NOT NULL,
    weighted_average_cost NUMERIC(19, 4),
    source_version INTEGER NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------------------------
-- 006. LAYER 4 & 5: ANALYTICAL DIMENSIONS (jonkai_analytics)
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS jonkai_analytics.dim_date (
    date_key INTEGER PRIMARY KEY, -- YYYYMMDD
    full_date DATE UNIQUE NOT NULL,
    day_name TEXT NOT NULL,
    day_of_week INTEGER NOT NULL,
    is_weekend BOOLEAN NOT NULL,
    week_of_year INTEGER NOT NULL,
    month_name TEXT NOT NULL,
    month_actual INTEGER NOT NULL,
    quarter INTEGER NOT NULL,
    year_actual INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS jonkai_analytics.dim_time (
    time_key INTEGER PRIMARY KEY, -- 0-86399 (Second of day)
    time_of_day TIME UNIQUE NOT NULL,
    hour_24 INTEGER NOT NULL,
    minute_of_hour INTEGER NOT NULL
);

-- -----------------------------------------------------------------------------
-- 007. LAYER 4 & 5: ANALYTICAL FACTS (jonkai_analytics)
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS jonkai_analytics.fact_sales (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL,
    branch_id UUID,
    date_key INTEGER REFERENCES jonkai_analytics.dim_date(date_key),
    time_key INTEGER REFERENCES jonkai_analytics.dim_time(time_key),
    sale_timestamp TIMESTAMPTZ NOT NULL,
    total_amount NUMERIC(19, 4) NOT NULL,
    cost_amount NUMERIC(19, 4) NOT NULL, -- Preserved Cost (WAC) at sale
    gross_profit NUMERIC(19, 4) GENERATED ALWAYS AS (total_amount - cost_amount) STORED,
    source_sale_id UUID NOT NULL,
    UNIQUE(business_id, source_sale_id)
);

-- -----------------------------------------------------------------------------
-- 008. LAYER 8 & 9: KNOWLEDGE & RULES (jonkai_rules)
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS jonkai_rules.definitions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL,
    rule_code TEXT NOT NULL,          -- Machine-readable unique code
    name TEXT NOT NULL,               -- Human-readable name
    category TEXT NOT NULL,           -- INVENTORY, SALES, SECURITY, etc.
    priority INTEGER DEFAULT 100,
    is_enabled BOOLEAN DEFAULT TRUE,
    rule_version INTEGER NOT NULL DEFAULT 1,
    source TEXT,                      -- USER, SYSTEM, PATTERN
    approval_status jonkai_knowledge.approval_status DEFAULT 'PENDING',
    conditions JSONB NOT NULL,        -- Structured conditions
    actions JSONB NOT NULL,           -- Actions to suggest
    prolog_predicate TEXT,            -- Executable Prolog source
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS jonkai_rules.rule_results (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL,
    rule_id UUID NOT NULL REFERENCES jonkai_rules.definitions(id),
    rule_version INTEGER NOT NULL,
    input_signal JSONB NOT NULL,
    matched_conditions JSONB,
    result_code TEXT NOT NULL,        -- Outcome of the rule
    evidence JSONB,                   -- Supporting data
    evaluated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    model_run_id UUID,                -- Link to Python model run if applicable
    branch_id UUID,
    user_id UUID
);

-- -----------------------------------------------------------------------------
-- 009. LAYER 12 & 13: AI OUTPUTS & RUNS (jonkai_ai)
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS jonkai_ai.model_runs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    model_name TEXT NOT NULL,
    model_version TEXT NOT NULL,
    run_timestamp TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    input_feature_set TEXT,
    performance_metrics JSONB
);

CREATE TABLE IF NOT EXISTS jonkai_ai.predictions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL,
    run_id UUID REFERENCES jonkai_ai.model_runs(id),
    target_entity_type TEXT NOT NULL, -- 'PRODUCT', 'BRANCH'
    target_entity_id UUID NOT NULL,
    prediction_type TEXT NOT NULL,    -- 'DEMAND', 'CHURN', 'REVENUE'
    forecast_start DATE,
    forecast_end DATE,
    predicted_value NUMERIC(19, 4) NOT NULL,
    actual_value NUMERIC(19, 4),      -- Backfilled for validation
    confidence_score NUMERIC(3, 2),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS jonkai_ai.recommendations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL,
    type TEXT NOT NULL,               -- 'RESTOCK', 'REPRICE'
    target_entity_id UUID,
    priority jonkai_ai.recommendation_priority DEFAULT 'MEDIUM',
    title TEXT NOT NULL,
    reasoning TEXT NOT NULL,
    evidence JSONB,
    status jonkai_ai.artifact_status DEFAULT 'ACTIVE',
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------------------------
-- 010. LAYER 14: CONVERSATIONS (jonkai_chat)
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS jonkai_chat.threads (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL,
    user_id UUID NOT NULL,
    title TEXT,
    started_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    last_message_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS jonkai_chat.messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    thread_id UUID REFERENCES jonkai_chat.threads(id) ON DELETE CASCADE,
    role TEXT NOT NULL, -- 'system', 'user', 'assistant', 'tool'
    content TEXT NOT NULL,
    tool_calls JSONB,   -- Log tool interactions (Prolog/Python functions)
    token_usage_estimate INTEGER,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------------------------
-- 011. AUDIT & LINEAGE (jonkai_audit)
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS jonkai_audit.pipeline_logs (
    id BIGSERIAL PRIMARY KEY,
    payload_id UUID REFERENCES jonkai_ingest.payloads(id),
    business_id UUID NOT NULL,
    step_name TEXT NOT NULL, -- 'VALIDATION', 'CORE_MIRROR'
    status TEXT NOT NULL,
    details TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------------------------
-- 012. RLS IMPLEMENTATION (Hardened)
-- -----------------------------------------------------------------------------

DO $$
DECLARE
    schema_name TEXT;
    table_name TEXT;
BEGIN
    FOR schema_name, table_name IN
        SELECT n.nspname, c.relname
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname IN ('jonkai_ingest', 'jonkai_core', 'jonkai_analytics', 'jonkai_rules', 'jonkai_ai', 'jonkai_chat', 'jonkai_audit')
        AND c.relkind = 'r'
        AND EXISTS (SELECT 1 FROM pg_attribute a WHERE a.attrelid = c.oid AND a.attname = 'business_id')
    LOOP
        EXECUTE format('ALTER TABLE %I.%I ENABLE ROW LEVEL SECURITY', schema_name, table_name);
        EXECUTE format('ALTER TABLE %I.%I FORCE ROW LEVEL SECURITY', schema_name, table_name);
        EXECUTE format('DROP POLICY IF EXISTS tenant_policy ON %I.%I', schema_name, table_name);
        EXECUTE format('CREATE POLICY tenant_policy ON %I.%I FOR ALL
            USING (business_id = coalesce(current_setting(''app.current_business_id'', true), ''00000000-0000-0000-0000-000000000000'')::uuid)
            WITH CHECK (business_id = coalesce(current_setting(''app.current_business_id'', true), ''00000000-0000-0000-0000-000000000000'')::uuid)',
            schema_name, table_name, schema_name, table_name);
    END LOOP;
END $$;

-- -----------------------------------------------------------------------------
-- 013. AI-SPECIFIC PERFORMANCE INDEXES
-- -----------------------------------------------------------------------------

-- Core lookup indexes
CREATE INDEX IF NOT EXISTS idx_fact_sales_timestamp ON jonkai_analytics.fact_sales(sale_timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_ingest_source_lookup ON jonkai_ingest.payloads(source_system, source_record_id);
CREATE INDEX IF NOT EXISTS idx_core_barcode_val ON jonkai_core.product_barcodes(barcode);
CREATE INDEX IF NOT EXISTS idx_rules_business ON jonkai_rules.definitions(business_id, category, is_enabled);

-- JSONB GIN Indexes for fast search within unstructured data
CREATE INDEX IF NOT EXISTS idx_ingest_payload_gin ON jonkai_ingest.payloads USING GIN (payload);
CREATE INDEX IF NOT EXISTS idx_rules_conditions_gin ON jonkai_rules.definitions USING GIN (conditions);
CREATE INDEX IF NOT EXISTS idx_chat_tool_calls_gin ON jonkai_chat.messages USING GIN (tool_calls);

-- Trigram Search for conversational memory and knowledge discovery
CREATE INDEX IF NOT EXISTS idx_chat_messages_content_trgm ON jonkai_chat.messages USING GIN (content gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_ai_reco_reasoning_trgm ON jonkai_ai.recommendations USING GIN (reasoning gin_trgm_ops);

-- Composite Indexes for multi-tenant reporting
CREATE INDEX IF NOT EXISTS idx_fact_sales_biz_date ON jonkai_analytics.fact_sales(business_id, date_key);
CREATE INDEX IF NOT EXISTS idx_core_sales_biz_date ON jonkai_core.sales(business_id, sale_date DESC);
CREATE INDEX IF NOT EXISTS idx_core_inv_biz_prod ON jonkai_core.inventory(business_id, product_id, branch_id);

-- -----------------------------------------------------------------------------
-- 014. TRIGGERS, FUNCTIONS & PROCEDURES
-- -----------------------------------------------------------------------------

-- 1. Automatic Timestamp Update Function
CREATE OR REPLACE FUNCTION update_timestamp_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply timestamp triggers
CREATE TRIGGER trg_update_biz_ts BEFORE UPDATE ON jonkai_core.businesses FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();
CREATE TRIGGER trg_update_prod_ts BEFORE UPDATE ON jonkai_core.products FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();
CREATE TRIGGER trg_update_chat_ts BEFORE UPDATE ON jonkai_chat.threads FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();

-- 2. Prolog Fact Generator (AI Reasoning Bridge)
-- Converts product and inventory data into Prolog-style logic predicates
CREATE OR REPLACE FUNCTION jonkai_core.get_prolog_facts(p_business_id UUID)
RETURNS TABLE (predicate TEXT) AS $$
BEGIN
    RETURN QUERY
    SELECT format('product(''%s'', ''%s'', %s, %s).',
           p.product_id,
           replace(p.name, '''', ''''''),
           coalesce(p.selling_price, 0),
           i.quantity)
    FROM jonkai_core.products p
    JOIN jonkai_core.inventory i ON p.product_id = i.product_id
    WHERE p.business_id = p_business_id AND p.is_active = TRUE;
END;
$$ LANGUAGE plpgsql;

-- 3. Maintenance: Generate Time Dimension (0-86399 seconds)
CREATE OR REPLACE PROCEDURE jonkai_analytics.generate_dim_time()
LANGUAGE plpgsql AS $$
DECLARE
    v_time TIME := '00:00:00';
    v_key INTEGER := 0;
BEGIN
    WHILE v_key < 86400 LOOP
        INSERT INTO jonkai_analytics.dim_time (time_key, time_of_day, hour_24, minute_of_hour)
        VALUES (v_key, v_time, EXTRACT(HOUR FROM v_time), EXTRACT(MINUTE FROM v_time))
        ON CONFLICT DO NOTHING;
        v_time := v_time + INTERVAL '1 second';
        v_key := v_key + 1;
    END LOOP;
END;
$$;

-- 4. Maintenance: Generate Date Dimension
CREATE OR REPLACE PROCEDURE jonkai_analytics.generate_dim_date(p_start_year INTEGER, p_end_year INTEGER)
LANGUAGE plpgsql AS $$
DECLARE
    v_date DATE;
BEGIN
    FOR v_date IN SELECT generate_series(
        format('%s-01-01', p_start_year)::DATE,
        format('%s-12-31', p_end_year)::DATE,
        '1 day'::interval
    ) LOOP
        INSERT INTO jonkai_analytics.dim_date (
            date_key, full_date, day_name, day_of_week, is_weekend,
            week_of_year, month_name, month_actual, quarter, year_actual
        ) VALUES (
            to_char(v_date, 'YYYYMMDD')::INTEGER,
            v_date,
            to_char(v_date, 'Day'),
            extract(isodow from v_date),
            CASE WHEN extract(isodow from v_date) IN (6, 7) THEN TRUE ELSE FALSE END,
            extract(week from v_date),
            to_char(v_date, 'Month'),
            extract(month from v_date),
            extract(quarter from v_date),
            extract(year from v_date)
        ) ON CONFLICT DO NOTHING;
    END LOOP;
END;
$$;

-- 5. AI Sales Velocity View (Feature Engineering)
CREATE OR REPLACE VIEW jonkai_metrics.vw_product_velocity AS
SELECT
    business_id,
    product_id,
    sum(quantity) / 30.0 as avg_daily_velocity,
    count(distinct sale_id) as sales_frequency,
    sum(quantity * unit_price) as revenue_contribution
FROM jonkai_core.sale_items
GROUP BY business_id, product_id;

COMMIT;
