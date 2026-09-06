-- 017_views.sql
-- Production Analytical Views for JonkStore POS

-- Daily Sales Summary
CREATE VIEW daily_sales_summary AS
SELECT
    branch_id,
    DATE(sale_date) as report_date,
    COUNT(id) as total_transactions,
    SUM(subtotal) as gross_sales,
    SUM(discount_total) as total_discounts,
    SUM(tax_total) as total_taxes,
    SUM(total_amount) as net_sales,
    SUM(paid_amount) as total_collected
FROM sales
WHERE is_deleted = 0 AND status = 'COMPLETED'
GROUP BY branch_id, DATE(sale_date);

-- Monthly Sales Summary
CREATE VIEW monthly_sales_summary AS
SELECT
    branch_id,
    STRFTIME('%Y-%m', sale_date) as report_month,
    COUNT(id) as total_transactions,
    SUM(total_amount) as net_sales,
    SUM(tax_total) as total_taxes
FROM sales
WHERE is_deleted = 0 AND status = 'COMPLETED'
GROUP BY branch_id, STRFTIME('%Y-%m', sale_date);

-- Yearly Sales Summary
CREATE VIEW yearly_sales_summary AS
SELECT
    business_id,
    STRFTIME('%Y', sale_date) as report_year,
    SUM(total_amount) as net_sales
FROM sales
WHERE is_deleted = 0 AND status = 'COMPLETED'
GROUP BY business_id, STRFTIME('%Y', sale_date);

-- Low Stock Products
CREATE VIEW low_stock_products AS
SELECT
    p.id as product_id,
    p.name as product_name,
    v.name as variant_name,
    b.name as branch_name,
    i.quantity as current_stock,
    i.low_stock_threshold
FROM inventory i
JOIN products p ON i.product_id = p.id
LEFT JOIN product_variants v ON i.variant_id = v.id
JOIN branches b ON i.branch_id = b.id
WHERE i.is_deleted = 0
  AND i.quantity <= i.low_stock_threshold;

-- Best Selling Products (By Quantity)
CREATE VIEW best_selling_products AS
SELECT
    si.product_id,
    si.name as product_name,
    SUM(si.quantity) as total_quantity_sold,
    SUM(si.total_amount) as total_revenue
FROM sale_items si
JOIN sales s ON si.sale_id = s.id
WHERE s.is_deleted = 0 AND s.status = 'COMPLETED'
GROUP BY si.product_id, si.name
ORDER BY total_quantity_sold DESC;

-- Worst Selling Products (Last 90 days)
CREATE VIEW worst_selling_products AS
SELECT
    p.id as product_id,
    p.name as product_name,
    COALESCE(SUM(si.quantity), 0) as total_quantity_sold
FROM products p
LEFT JOIN sale_items si ON p.id = si.product_id
LEFT JOIN sales s ON si.sale_id = s.id AND s.sale_date >= DATE('now', '-90 days')
WHERE p.is_deleted = 0
GROUP BY p.id, p.name
ORDER BY total_quantity_sold ASC;

-- Customer Balances (For Credit Sales)
CREATE VIEW customer_balances AS
SELECT
    c.id as customer_id,
    c.first_name || ' ' || COALESCE(c.last_name, '') as customer_name,
    SUM(CASE WHEN s.payment_status != 'PAID' THEN (s.total_amount - s.paid_amount) ELSE 0 END) as outstanding_balance
FROM customers c
LEFT JOIN sales s ON c.id = s.customer_id
WHERE c.is_deleted = 0
GROUP BY c.id, customer_name;

-- Supplier Balances
CREATE VIEW supplier_balances AS
SELECT
    s.id as supplier_id,
    s.name as supplier_name,
    s.current_balance as outstanding_balance
FROM suppliers s
WHERE s.is_deleted = 0;

-- Inventory Value (At Cost)
CREATE VIEW inventory_value AS
SELECT
    b.id as branch_id,
    b.name as branch_name,
    SUM(i.quantity * COALESCE(v.cost_price, 0)) as total_inventory_value_cost,
    SUM(i.quantity * v.price) as total_inventory_value_retail
FROM inventory i
JOIN branches b ON i.branch_id = b.id
JOIN product_variants v ON i.variant_id = v.id
WHERE i.is_deleted = 0
GROUP BY b.id, b.name;

-- Profit Report
CREATE VIEW profit_report AS
SELECT
    s.branch_id,
    DATE(s.sale_date) as report_date,
    SUM(si.total_amount) as revenue,
    SUM(si.quantity * si.cost_price) as cost_of_goods_sold,
    (SUM(si.total_amount) - SUM(si.quantity * si.cost_price)) as gross_profit
FROM sales s
JOIN sale_items si ON s.id = si.sale_id
WHERE s.is_deleted = 0 AND s.status = 'COMPLETED'
GROUP BY s.branch_id, DATE(s.sale_date);

-- Runner Fee Report
CREATE VIEW runner_fee_report AS
SELECT
    rf.runner_name,
    po.order_number,
    rf.amount as fee_amount,
    rf.payment_status,
    rf.payment_date
FROM runner_fees rf
JOIN purchase_orders po ON rf.purchase_order_id = po.id;

-- Business Health Report
CREATE VIEW business_health_report AS
SELECT
    bh.business_id,
    bh.health_score,
    bh.metric_date,
    bh.metrics_json
FROM business_health bh
ORDER BY bh.metric_date DESC;
