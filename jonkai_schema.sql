-- ============================================================================
-- JONKAI POSTGRESQL DATABASE SCHEMA — FINAL PRODUCTION RELEASE
-- Version: 3.6.0 (AI Optimized, Materialized & Maintenance-Ready)
-- Principal AI Database Architect & Data Engineer
-- ============================================================================

SET client_min_messages TO WARNING;

BEGIN;

-- -----------------------------------------------------------------------------
-- 001. EXTENSIONS & SCHEMAS
-- -----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gist";

-- Ensure all logical layers exist
CREATE SCHEMA IF NOT EXISTS jonkai_ingest;
CREATE SCHEMA IF NOT EXISTS jonkai_core;
CREATE SCHEMA IF NOT EXISTS jonkai_analytics;
CREATE SCHEMA IF NOT EXISTS jonkai_metrics;
CREATE SCHEMA IF NOT EXISTS jonkai_features;
CREATE SCHEMA IF NOT EXISTS jonkai_knowledge;
CREATE SCHEMA IF NOT EXISTS jonkai_rules;
CREATE SCHEMA IF NOT EXISTS jonkai_ai;
CREATE SCHEMA IF NOT EXISTS jonkai_chat;

-- -----------------------------------------------------------------------------
-- 002. KNOWLEDGE GRAPH INFRASTRUCTURE
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS jonkai_knowledge.triples (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL,
    subject_id UUID NOT NULL,
    predicate TEXT NOT NULL,         -- e.g., 'HAS_PREFERENCE', 'BOUGHT_WITH'
    object_id UUID,
    object_value TEXT,
    confidence NUMERIC(3,2) DEFAULT 1.0,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_triples_lookup ON jonkai_knowledge.triples (business_id, subject_id, predicate);

-- -----------------------------------------------------------------------------
-- 003. MATERIALIZED ANALYTICS (Extreme Performance)
-- -----------------------------------------------------------------------------

-- This view pre-calculates daily performance to avoid heavy runtime scans
CREATE MATERIALIZED VIEW IF NOT EXISTS jonkai_metrics.mvw_daily_kpis AS
SELECT
    business_id,
    branch_id,
    date_trunc('day', sale_timestamp) as day,
    COUNT(id) as transaction_count,
    SUM(total_amount) as revenue,
    SUM(gross_profit) as profit
FROM jonkai_analytics.fact_sales
GROUP BY 1, 2, 3
WITH NO DATA;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mvw_daily_kpis_unique ON jonkai_metrics.mvw_daily_kpis (business_id, branch_id, day);

-- -----------------------------------------------------------------------------
-- 004. ENHANCED PROLOG BRIDGE (Reasoning Facts)
-- -----------------------------------------------------------------------------

-- Export Sales Facts for Prolog Logic
CREATE OR REPLACE FUNCTION jonkai_core.get_sale_predicates(p_business_id UUID)
RETURNS TABLE (predicate TEXT) AS $$
BEGIN
    RETURN QUERY
    SELECT format('sale(''%s'', ''%s'', %s, ''%s'').',
           sale_id,
           customer_id,
           total_amount,
           sale_date::date)
    FROM jonkai_core.sales
    WHERE business_id = p_business_id
    ORDER BY sale_date DESC LIMIT 1000;
END;
$$ LANGUAGE plpgsql;

-- Export Customer Facts for Prolog Logic
CREATE OR REPLACE FUNCTION jonkai_core.get_customer_predicates(p_business_id UUID)
RETURNS TABLE (predicate TEXT) AS $$
BEGIN
    RETURN QUERY
    SELECT format('customer(''%s'', %s, %s).',
           customer_id,
           frequency,
           monetary)
    FROM jonkai_features.vw_customer_rfm
    WHERE business_id = p_business_id;
END;
$$ LANGUAGE plpgsql;

-- -----------------------------------------------------------------------------
-- 005. MAINTENANCE PROCEDURES (Populate Dimensions)
-- -----------------------------------------------------------------------------

-- Time Dimension Generator (0 to 86399 seconds)
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

-- Date Dimension Generator (Calendar generator)
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

-- -----------------------------------------------------------------------------
-- 006. REAL-TIME AI SIGNALING & SEARCH
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION jonkai_analytics.fn_check_sale_anomaly()
RETURNS TRIGGER AS $$
DECLARE
    v_avg_sale NUMERIC;
BEGIN
    SELECT AVG(total_amount) INTO v_avg_sale
    FROM jonkai_analytics.fact_sales
    WHERE business_id = NEW.business_id;

    IF NEW.total_amount > (v_avg_sale * 5) THEN
        INSERT INTO jonkai_ai.recommendations (business_id, type, title, reasoning, priority)
        VALUES (NEW.business_id, 'ANOMALY', 'High Value Transaction',
                format('Sale of %s detected, which is 5x the business average.', NEW.total_amount), 'HIGH');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sale_anomaly ON jonkai_analytics.fact_sales;
CREATE TRIGGER trg_sale_anomaly
AFTER INSERT ON jonkai_analytics.fact_sales
FOR EACH ROW EXECUTE FUNCTION jonkai_analytics.fn_check_sale_anomaly();

CREATE INDEX IF NOT EXISTS idx_chat_messages_search ON jonkai_chat.messages USING GIN (content gin_trgm_ops);

COMMIT;
