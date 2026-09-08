/// Centralized constants for the SQLite database.
/// Aligned with the commercial-grade 3NF schema for JonkStore POS.
class DatabaseConstants {
  DatabaseConstants._();

  // --- Table Names ---
  static const String tableBusinesses = 'businesses';
  static const String tableBranches = 'branches';
  static const String tableBusinessSettings = 'business_settings';
  static const String tableReceiptSettings = 'receipt_settings';
  static const String tableCurrencies = 'currencies';
  static const String tableTaxes = 'taxes';
  static const String tableEmployees = 'employees';
  static const String tableOwnerProfile = 'owner_profile';
  static const String tableCategories = 'categories';
  static const String tableSubcategories = 'subcategories';
  static const String tableBrands = 'brands';
  static const String tableSuppliers = 'suppliers';
  static const String tableSupplierContacts = 'supplier_contacts';
  static const String tableProductUnits = 'product_units';
  static const String tableProductCategories = 'product_categories';
  static const String tableProducts = 'products';
  static const String tableProductVariants = 'product_variants';
  static const String tableProductBarcodes = 'product_barcodes';
  static const String tableProductImages = 'product_images';
  static const String tableProductPrices = 'product_prices';
  static const String tablePurchaseOrders = 'purchase_orders';
  static const String tablePurchaseOrderItems = 'purchase_order_items';
  static const String tablePurchasePayments = 'purchase_payments';
  static const String tableRunnerFees = 'runner_fees';
  static const String tableRunnerFeeAllocations = 'runner_fee_allocations';
  static const String tableInventory = 'inventory';
  static const String tableInventoryTransactions = 'inventory_transactions';
  static const String tableInventoryAdjustments = 'inventory_adjustments';
  static const String tableInventoryCounts = 'inventory_counts';
  static const String tableStockTransfers = 'stock_transfers';
  static const String tableStockAlerts = 'stock_alerts';
  static const String tableCustomers = 'customers';
  static const String tableCustomerAddresses = 'customer_addresses';
  static const String tableCustomerLoyalty = 'customer_loyalty';
  static const String tableCustomerTransactions = 'customer_transactions';
  static const String tableSales = 'sales';
  static const String tableSaleItems = 'sale_items';
  static const String tableSaleDiscounts = 'sale_discounts';
  static const String tableSaleTaxes = 'sale_taxes';
  static const String tableSaleReturns = 'sale_returns';
  static const String tablePayments = 'payments';
  static const String tableExpenses = 'expenses';
  static const String tableNotifications = 'notifications';
  static const String tableAIRecommendations = 'ai_recommendations';
  static const String tableBusinessHealth = 'business_health';
  static const String tableSyncQueue = 'sync_queue';
  static const String tableAppSettings = 'app_settings';
  static const String tableMigrations = 'migrations';
  static const String tableUsers = 'users';
  static const String tableOtps = 'otps';

  // --- Common Column Names ---
  static const String columnId = 'id';
  static const String columnCreatedAt = 'created_at';
  static const String columnUpdatedAt = 'updated_at';
  static const String columnDeletedAt = 'deleted_at';
  static const String columnIsDeleted = 'is_deleted';
  static const String columnIsActive = 'is_active';
  static const String columnCreatedBy = 'created_by';
  static const String columnUpdatedBy = 'updated_by';
  static const String columnVersion = 'version';

  // --- Sync Columns ---
  static const String columnSyncStatus = 'sync_status';
  static const String columnServerId = 'server_id';
  static const String columnLastSyncedAt = 'last_synced_at';

  // --- Auth & Profile Columns ---
  static const String columnFirebaseUid = 'firebase_uid';
  static const String columnUsername = 'username';
  static const String columnRole = 'role';
  static const String columnIsVerified = 'is_verified';
  static const String columnEmail = 'email';
  static const String columnPhone = 'phone';
  static const String columnPasswordHash = 'password_hash';

  // --- Entity Specific Columns ---
  static const String columnBusinessId = 'business_id';
  static const String columnBranchId = 'branch_id';
  static const String columnCategoryId = 'category_id';
  static const String columnSupplierId = 'supplier_id';
  static const String columnProductId = 'product_id';
  static const String columnVariantId = 'variant_id';
  static const String columnInventoryId = 'inventory_id';
  static const String columnSaleId = 'sale_id';
  static const String columnCustomerId = 'customer_id';
  static const String columnUserId = 'user_id';
  static const String columnEmployeeId = 'employee_id';

  static const String columnName = 'name';
  static const String columnCode = 'code';
  static const String columnContactName = 'contact_name';
  static const String columnSku = 'sku';
  static const String columnBarcode = 'barcode';
  static const String columnPrice = 'price';
  static const String columnCostPrice = 'cost_price';
  static const String columnQuantity = 'quantity';
  static const String columnTotalAmount = 'total_amount';
  static const String columnPaidAmount = 'paid_amount';
  static const String columnOrderNumber = 'order_number';
  static const String columnPurchaseDate = 'purchase_date';
  static const String columnStatus = 'status';
  
  static const String columnTransactionDate = 'transaction_date';
  static const String columnLowStockThreshold = 'low_stock_threshold';
}
