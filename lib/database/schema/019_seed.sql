-- 019_seed.sql
-- Production System Seed Data for JonkStore POS

-- 1. SEED CORE CURRENCIES
INSERT INTO currencies (id, code, name, symbol, exchange_rate, is_active, created_at, updated_at, sync_status, version)
VALUES
('CUR001', 'KES', 'Kenyan Shilling', 'KES', 1.0, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'SYNCED', 1),
('CUR002', 'USD', 'US Dollar', '$', 0.0075, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'SYNCED', 1),
('CUR003', 'UGX', 'Ugandan Shilling', 'UGX', 0.28, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'SYNCED', 1);

-- 2. SEED SYSTEM PERMISSIONS
INSERT INTO permissions (id, name, slug, module, description, created_at, updated_at, sync_status, version)
VALUES
('PRM001', 'Create Sales', 'sales.create', 'Sales', 'Allows processing new transactions', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'SYNCED', 1),
('PRM002', 'View Sales', 'sales.view', 'Sales', 'Allows viewing transaction history', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'SYNCED', 1),
('PRM003', 'Process Refunds', 'sales.refund', 'Sales', 'Allows processing returns and refunds', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'SYNCED', 1),
('PRM004', 'Manage Products', 'products.manage', 'Products', 'Allows adding and editing products', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'SYNCED', 1),
('PRM005', 'Change Prices', 'products.price', 'Products', 'Allows modifying product pricing', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'SYNCED', 1),
('PRM006', 'Adjust Stock', 'inventory.adjust', 'Inventory', 'Allows manual inventory corrections', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'SYNCED', 1),
('PRM007', 'Transfer Stock', 'inventory.transfer', 'Inventory', 'Allows moving stock between branches', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'SYNCED', 1),
('PRM008', 'View AI Insights', 'ai.view', 'AI', 'Allows access to AI business recommendations', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'SYNCED', 1);

-- 4. SEED SYSTEM SETTINGS
INSERT INTO system_settings (id, config_name, config_value, data_type, last_updated_at)
VALUES
('SYS001', 'app_version', '1.0.0', 'STRING', CURRENT_TIMESTAMP),
('SYS002', 'database_schema_version', '1', 'INTEGER', CURRENT_TIMESTAMP),
('SYS003', 'sync_interval_minutes', '5', 'INTEGER', CURRENT_TIMESTAMP),
('SYS004', 'enable_ai_insights', 'true', 'BOOLEAN', CURRENT_TIMESTAMP);
