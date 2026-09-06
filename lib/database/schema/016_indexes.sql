-- 016_indexes.sql
-- Optimized Indexes for Search and Relationships
-- Target: Commercial Performance with Millions of Records

-- BUSINESS & BRANCHES
CREATE INDEX idx_branches_business_id ON branches(business_id);
CREATE INDEX idx_business_settings_business_id ON business_settings(business_id);
CREATE INDEX idx_receipt_settings_branch_id ON receipt_settings(branch_id);

-- SECURITY & EMPLOYEES
CREATE INDEX idx_roles_business_id ON roles(business_id);
CREATE INDEX idx_role_permissions_role_id ON role_permissions(role_id);
CREATE INDEX idx_role_permissions_permission_id ON role_permissions(permission_id);
CREATE INDEX idx_employees_business_id ON employees(business_id);
CREATE INDEX idx_employees_branch_id ON employees(branch_id);
CREATE INDEX idx_employees_role_id ON employees(role_id);
CREATE INDEX idx_employees_email ON employees(email);
CREATE INDEX idx_employees_phone ON employees(phone);
CREATE INDEX idx_employee_permissions_employee_id ON employee_permissions(employee_id);
CREATE INDEX idx_authorized_devices_employee_id ON authorized_devices(employee_id);
CREATE INDEX idx_login_history_employee_id ON login_history(employee_id);

-- PRODUCTS & CATEGORIES
CREATE INDEX idx_categories_business_id ON categories(business_id);
CREATE INDEX idx_subcategories_category_id ON subcategories(category_id);
CREATE INDEX idx_products_business_id ON products(business_id);
CREATE INDEX idx_products_brand_id ON products(brand_id);
CREATE INDEX idx_products_unit_id ON products(unit_id);
CREATE INDEX idx_products_sku ON products(sku);
CREATE INDEX idx_product_categories_product_id ON product_categories(product_id);
CREATE INDEX idx_product_categories_category_id ON product_categories(category_id);
CREATE INDEX idx_product_variants_product_id ON product_variants(product_id);
CREATE INDEX idx_product_variants_sku ON product_variants(sku);
CREATE INDEX idx_product_barcodes_product_id ON product_barcodes(product_id);
CREATE INDEX idx_product_barcodes_variant_id ON product_barcodes(variant_id);
CREATE INDEX idx_product_barcodes_barcode ON product_barcodes(barcode);
CREATE INDEX idx_product_images_product_id ON product_images(product_id);
CREATE INDEX idx_product_prices_product_id ON product_prices(product_id);
CREATE INDEX idx_product_prices_variant_id ON product_prices(variant_id);
CREATE INDEX idx_product_prices_branch_id ON product_prices(branch_id);

-- SUPPLIERS & PURCHASES
CREATE INDEX idx_suppliers_business_id ON suppliers(business_id);
CREATE INDEX idx_suppliers_name ON suppliers(name);
CREATE INDEX idx_suppliers_code ON suppliers(code);
CREATE INDEX idx_suppliers_phone ON suppliers(phone);
CREATE INDEX idx_suppliers_email ON suppliers(email);
CREATE INDEX idx_suppliers_contact ON suppliers(contactName);
CREATE INDEX idx_suppliers_active ON suppliers(is_active, is_deleted);
CREATE INDEX idx_supplier_contacts_supplier_id ON supplier_contacts(supplier_id);
CREATE INDEX idx_purchase_orders_business_id ON purchase_orders(business_id);
CREATE INDEX idx_purchase_orders_branch_id ON purchase_orders(branch_id);
CREATE INDEX idx_purchase_orders_supplier_id ON purchase_orders(supplier_id);
CREATE INDEX idx_purchase_order_items_po_id ON purchase_order_items(purchase_order_id);
CREATE INDEX idx_purchase_order_items_product_id ON purchase_order_items(product_id);
CREATE INDEX idx_purchase_payments_po_id ON purchase_payments(purchase_order_id);
CREATE INDEX idx_runner_fees_po_id ON runner_fees(purchase_order_id);

-- INVENTORY
CREATE INDEX idx_inventory_product_id ON inventory(product_id);
CREATE INDEX idx_inventory_variant_id ON inventory(variant_id);
CREATE INDEX idx_inventory_branch_id ON inventory(branch_id);
CREATE INDEX idx_inventory_transactions_inv_id ON inventory_transactions(inventory_id);
CREATE INDEX idx_inventory_transactions_date ON inventory_transactions(transaction_date);
CREATE INDEX idx_stock_transfers_from_branch ON stock_transfers(from_branch_id);
CREATE INDEX idx_stock_transfers_to_branch ON stock_transfers(to_branch_id);

-- CUSTOMERS & SALES
CREATE INDEX idx_customers_business_id ON customers(business_id);
CREATE INDEX idx_customers_phone ON customers(phone);
CREATE INDEX idx_customer_addresses_customer_id ON customer_addresses(customer_id);
CREATE INDEX idx_sales_business_id ON sales(business_id);
CREATE INDEX idx_sales_branch_id ON sales(branch_id);
CREATE INDEX idx_sales_customer_id ON sales(customer_id);
CREATE INDEX idx_sales_employee_id ON sales(employee_id);
CREATE INDEX idx_sales_date ON sales(sale_date);
CREATE INDEX idx_sale_items_sale_id ON sale_items(sale_id);
CREATE INDEX idx_sale_items_product_id ON sale_items(product_id);
CREATE INDEX idx_sale_payments_sale_id ON sale_payments(sale_id);
CREATE INDEX idx_sale_returns_sale_id ON sale_returns(sale_id);

-- EXPENSES
CREATE INDEX idx_expenses_business_id ON expenses(business_id);
CREATE INDEX idx_expenses_branch_id ON expenses(branch_id);
CREATE INDEX idx_expenses_category_id ON expenses(category_id);

-- SYNC & AUDIT
CREATE INDEX idx_sync_queue_table_record ON sync_queue(table_name, record_id);
CREATE INDEX idx_audit_logs_table_record ON audit_logs(table_name, record_id);
CREATE INDEX idx_activity_logs_employee_id ON activity_logs(employee_id);

-- COMPOSITE INDEXES FOR COMMON SEARCHES
CREATE INDEX idx_products_name_business ON products(name, business_id);
CREATE INDEX idx_sales_status_date ON sales(status, sale_date);
CREATE INDEX idx_inventory_branch_product ON inventory(branch_id, product_id);
