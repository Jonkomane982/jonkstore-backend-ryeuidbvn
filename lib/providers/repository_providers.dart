import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jonkstore/core/providers/core_providers.dart';
import 'package:jonkstore/sync/providers/sync_providers.dart';
import 'service_providers.dart';
import 'package:jonkstore/repositories/business_repository.dart';
import 'package:jonkstore/repositories/business_repository_impl.dart';
import 'package:jonkstore/repositories/user_repository.dart';
import 'package:jonkstore/repositories/user_repository_impl.dart';
import 'package:jonkstore/repositories/dashboard_repository.dart';
import 'package:jonkstore/repositories/dashboard_repository_impl.dart';
import 'package:jonkstore/repositories/product_repository.dart';
import 'package:jonkstore/repositories/product_repository_impl.dart';
import 'package:jonkstore/repositories/category_repository.dart';
import 'package:jonkstore/repositories/category_repository_impl.dart';
import 'package:jonkstore/repositories/sales_repository.dart';
import 'package:jonkstore/repositories/sales_repository_impl.dart';
import 'package:jonkstore/repositories/inventory_repository.dart';
import 'package:jonkstore/repositories/inventory_repository_impl.dart';
import 'package:jonkstore/repositories/customer_repository.dart';
import 'package:jonkstore/repositories/customer_repository_impl.dart';
import 'package:jonkstore/repositories/supplier_repository.dart';
import 'package:jonkstore/repositories/supplier_repository_impl.dart';
import 'package:jonkstore/repositories/purchase_repository.dart';
import 'package:jonkstore/repositories/purchase_repository_impl.dart';
import 'package:jonkstore/repositories/employee_repository.dart';
import 'package:jonkstore/repositories/employee_repository_impl.dart';
import 'package:jonkstore/repositories/notification_repository.dart';
import 'package:jonkstore/repositories/notification_repository_impl.dart';
import 'package:jonkstore/repositories/settings_repository.dart';
import 'package:jonkstore/repositories/settings_repository_impl.dart';
import 'package:jonkstore/repositories/ai_repository.dart';
import 'package:jonkstore/repositories/ai_repository_impl.dart';
import 'package:jonkstore/repositories/reports_repository.dart';
import 'package:jonkstore/repositories/reports_repository_impl.dart';
import 'package:jonkstore/datasources/local/business_local_datasource.dart';
import 'package:jonkstore/datasources/local/user_local_datasource.dart';
import 'package:jonkstore/datasources/local/product_local_datasource.dart';
import 'package:jonkstore/datasources/local/category_local_datasource.dart';
import 'package:jonkstore/datasources/local/sales_local_datasource.dart';
import 'package:jonkstore/datasources/local/inventory_local_datasource.dart';
import 'package:jonkstore/datasources/local/customer_local_datasource.dart';
import 'package:jonkstore/datasources/local/supplier_local_datasource.dart';
import 'package:jonkstore/datasources/local/purchase_local_datasource.dart';
import 'package:jonkstore/datasources/local/employee_local_datasource.dart';
import 'package:jonkstore/datasources/local/notification_local_datasource.dart';
import 'package:jonkstore/datasources/local/settings_local_datasource.dart';
import 'package:jonkstore/datasources/local/ai_local_datasource.dart';
import 'package:jonkstore/datasources/remote/business_remote_datasource.dart';
import 'package:jonkstore/datasources/remote/user_remote_datasource.dart';
import 'package:jonkstore/datasources/remote/product_remote_datasource.dart';
import 'package:jonkstore/datasources/remote/sales_remote_datasource.dart';
import 'package:jonkstore/datasources/remote/inventory_remote_datasource.dart';
import 'package:jonkstore/datasources/remote/customer_remote_datasource.dart';
import 'package:jonkstore/datasources/remote/supplier_remote_datasource.dart';
import 'package:jonkstore/datasources/remote/purchase_remote_datasource.dart';
import 'package:jonkstore/datasources/remote/employee_remote_datasource.dart';
import 'package:jonkstore/datasources/remote/notification_remote_datasource.dart';
import 'package:jonkstore/datasources/remote/settings_remote_datasource.dart';
import 'package:jonkstore/datasources/remote/ai_remote_datasource.dart';
import 'package:jonkstore/database/dao/dashboard_dao.dart';
import 'package:jonkstore/database/dao/reports_dao.dart';
import 'package:jonkstore/database/dao/category_dao.dart';
import 'package:jonkstore/database/dao/supplier_dao.dart';
import 'package:jonkstore/database/dao/inventory_dao.dart';
import 'package:jonkstore/database/dao/inventory_transaction_dao.dart';
import 'package:jonkstore/database/dao/inventory_adjustment_dao.dart';
import 'package:jonkstore/database/dao/inventory_count_dao.dart';
import 'package:jonkstore/database/dao/stock_transfer_dao.dart';
import 'package:jonkstore/database/dao/purchase_dao.dart';

/// --- DAOs ---
final categoryDaoProvider = Provider<CategoryDao>((ref) {
  return CategoryDao(ref.watch(databaseServiceProvider));
});

final supplierDaoProvider = Provider<SupplierDao>((ref) {
  return SupplierDao(ref.watch(databaseServiceProvider));
});

final inventoryDaoProvider = Provider<InventoryDao>((ref) {
  return InventoryDao(ref.watch(databaseServiceProvider));
});

final inventoryTransactionDaoProvider = Provider<InventoryTransactionDao>((
  ref,
) {
  return InventoryTransactionDao(ref.watch(databaseServiceProvider));
});

final inventoryAdjustmentDaoProvider = Provider<InventoryAdjustmentDao>((ref) {
  return InventoryAdjustmentDao(ref.watch(databaseServiceProvider));
});

final inventoryCountDaoProvider = Provider<InventoryCountDao>((ref) {
  return InventoryCountDao(ref.watch(databaseServiceProvider));
});

final stockTransferDaoProvider = Provider<StockTransferDao>((ref) {
  return StockTransferDao(ref.watch(databaseServiceProvider));
});

final purchaseDaoProvider = Provider<PurchaseDao>((ref) {
  return PurchaseDao(ref.watch(databaseServiceProvider));
});

/// --- Data Sources ---

final businessLocalDataSourceProvider = Provider<BusinessLocalDataSource>(
  (ref) => BusinessLocalDataSource(ref.watch(databaseServiceProvider)),
);
final businessRemoteDataSourceProvider = Provider<BusinessRemoteDataSource>(
  (ref) => BusinessRemoteDataSource(ref.watch(apiClientProvider)),
);

final userLocalDataSourceProvider = Provider<UserLocalDataSource>(
  (ref) => UserLocalDataSource(ref.watch(databaseServiceProvider)),
);
final userRemoteDataSourceProvider = Provider<UserRemoteDataSource>(
  (ref) => UserRemoteDataSource(ref.watch(apiClientProvider)),
);

final productLocalDataSourceProvider = Provider<ProductLocalDataSource>(
  (ref) => ProductLocalDataSource(ref.watch(databaseServiceProvider)),
);
final productRemoteDataSourceProvider = Provider<ProductRemoteDataSource>(
  (ref) => ProductRemoteDataSource(ref.watch(apiClientProvider)),
);

final categoryLocalDataSourceProvider = Provider<CategoryLocalDataSource>((
  ref,
) {
  return CategoryLocalDataSource(ref.watch(categoryDaoProvider));
});

final salesLocalDataSourceProvider = Provider<SalesLocalDataSource>(
  (ref) => SalesLocalDataSource(ref.watch(databaseServiceProvider)),
);
final salesRemoteDataSourceProvider = Provider<SalesRemoteDataSource>(
  (ref) => SalesRemoteDataSource(ref.watch(apiClientProvider)),
);

final inventoryLocalDataSourceProvider = Provider<InventoryLocalDataSource>(
  (ref) => InventoryLocalDataSource(ref.watch(databaseServiceProvider)),
);
final inventoryRemoteDataSourceProvider = Provider<InventoryRemoteDataSource>(
  (ref) => InventoryRemoteDataSource(ref.watch(apiClientProvider)),
);

final customerLocalDataSourceProvider = Provider<CustomerLocalDataSource>(
  (ref) => CustomerLocalDataSource(ref.watch(databaseServiceProvider)),
);
final customerRemoteDataSourceProvider = Provider<CustomerRemoteDataSource>(
  (ref) => CustomerRemoteDataSource(ref.watch(apiClientProvider)),
);

final supplierLocalDataSourceProvider = Provider<SupplierLocalDataSource>((
  ref,
) {
  return SupplierLocalDataSource(ref.watch(supplierDaoProvider));
});
final supplierRemoteDataSourceProvider = Provider<SupplierRemoteDataSource>(
  (ref) => SupplierRemoteDataSource(ref.watch(apiClientProvider)),
);

final purchaseLocalDataSourceProvider = Provider<PurchaseLocalDataSource>(
  (ref) => PurchaseLocalDataSource(ref.watch(purchaseDaoProvider)),
);
final purchaseRemoteDataSourceProvider = Provider<PurchaseRemoteDataSource>(
  (ref) => PurchaseRemoteDataSource(ref.watch(apiClientProvider)),
);

final employeeLocalDataSourceProvider = Provider<EmployeeLocalDataSource>(
  (ref) => EmployeeLocalDataSource(ref.watch(databaseServiceProvider)),
);
final employeeRemoteDataSourceProvider = Provider<EmployeeRemoteDataSource>(
  (ref) => EmployeeRemoteDataSource(ref.watch(apiClientProvider)),
);

final notificationLocalDataSourceProvider =
    Provider<NotificationLocalDataSource>(
      (ref) => NotificationLocalDataSource(ref.watch(databaseServiceProvider)),
    );
final notificationRemoteDataSourceProvider =
    Provider<NotificationRemoteDataSource>(
      (ref) => NotificationRemoteDataSource(ref.watch(apiClientProvider)),
    );

final settingsLocalDataSourceProvider = Provider<SettingsLocalDataSource>(
  (ref) => SettingsLocalDataSource(ref.watch(databaseServiceProvider)),
);
final settingsRemoteDataSourceProvider = Provider<SettingsRemoteDataSource>(
  (ref) => SettingsRemoteDataSource(ref.watch(apiClientProvider)),
);

final aiLocalDataSourceProvider = Provider<AILocalDataSource>(
  (ref) => AILocalDataSource(ref.watch(databaseServiceProvider)),
);
final aiRemoteDataSourceProvider = Provider<AIRemoteDataSource>(
  (ref) => AIRemoteDataSource(ref.watch(apiClientProvider)),
);

/// --- Repositories ---

final businessRepositoryProvider = Provider<BusinessRepository>(
  (ref) => BusinessRepositoryImpl(
    localDataSource: ref.watch(businessLocalDataSourceProvider),
    remoteDataSource: ref.watch(businessRemoteDataSourceProvider),
  ),
);

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepositoryImpl(
    localDataSource: ref.watch(userLocalDataSourceProvider),
    remoteDataSource: ref.watch(userRemoteDataSourceProvider),
  ),
);

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ProductRepositoryImpl(
    localDataSource: ref.watch(productLocalDataSourceProvider),
    remoteDataSource: ref.watch(productRemoteDataSourceProvider),
    syncQueue: ref.watch(syncQueueProvider),
  ),
);

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepositoryImpl(
    localDataSource: ref.watch(categoryLocalDataSourceProvider),
    syncQueue: ref.watch(syncQueueProvider),
  );
});

final salesRepositoryProvider = Provider<SalesRepository>(
  (ref) => SalesRepositoryImpl(
    localDataSource: ref.watch(salesLocalDataSourceProvider),
    remoteDataSource: ref.watch(salesRemoteDataSourceProvider),
    syncQueue: ref.watch(syncQueueProvider),
  ),
);

final inventoryRepositoryProvider = Provider<InventoryRepository>(
  (ref) => InventoryRepositoryImpl(
    inventoryDao: ref.watch(inventoryDaoProvider),
    transactionDao: ref.watch(inventoryTransactionDaoProvider),
    adjustmentDao: ref.watch(inventoryAdjustmentDaoProvider),
    countDao: ref.watch(inventoryCountDaoProvider),
    transferDao: ref.watch(stockTransferDaoProvider),
    databaseService: ref.watch(databaseServiceProvider),
    syncQueue: ref.watch(syncQueueProvider),
  ),
);

final customerRepositoryProvider = Provider<CustomerRepository>(
  (ref) => CustomerRepositoryImpl(
    localDataSource: ref.watch(customerLocalDataSourceProvider),
    remoteDataSource: ref.watch(customerRemoteDataSourceProvider),
    syncQueue: ref.watch(syncQueueProvider),
  ),
);

final supplierRepositoryProvider = Provider<SupplierRepository>(
  (ref) => SupplierRepositoryImpl(
    localDataSource: ref.watch(supplierLocalDataSourceProvider),
    remoteDataSource: ref.watch(supplierRemoteDataSourceProvider),
    syncQueue: ref.watch(syncQueueProvider),
  ),
);

final purchaseRepositoryProvider = Provider<PurchaseRepository>(
  (ref) => PurchaseRepositoryImpl(
    localDataSource: ref.watch(purchaseLocalDataSourceProvider),
    remoteDataSource: ref.watch(purchaseRemoteDataSourceProvider),
    inventoryDao: ref.watch(inventoryDaoProvider),
    transactionDao: ref.watch(inventoryTransactionDaoProvider),
    databaseService: ref.watch(databaseServiceProvider),
    calculationService: ref.watch(purchaseCalculationServiceProvider),
    syncQueue: ref.watch(syncQueueProvider),
  ),
);

final employeeRepositoryProvider = Provider<EmployeeRepository>(
  (ref) => EmployeeRepositoryImpl(
    localDataSource: ref.watch(employeeLocalDataSourceProvider),
    remoteDataSource: ref.watch(employeeRemoteDataSourceProvider),
    syncQueue: ref.watch(syncQueueProvider),
  ),
);

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepositoryImpl(
    localDataSource: ref.watch(notificationLocalDataSourceProvider),
    remoteDataSource: ref.watch(notificationRemoteDataSourceProvider),
    syncQueue: ref.watch(syncQueueProvider),
  ),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepositoryImpl(
    localDataSource: ref.watch(settingsLocalDataSourceProvider),
    remoteDataSource: ref.watch(settingsRemoteDataSourceProvider),
  ),
);

final aiRepositoryProvider = Provider<AIRepository>(
  (ref) => AIRepositoryImpl(
    localDataSource: ref.watch(aiLocalDataSourceProvider),
    remoteDataSource: ref.watch(aiRemoteDataSourceProvider),
  ),
);

final reportsDaoProvider = Provider<ReportsDao>(
  (ref) => ReportsDao(ref.watch(databaseServiceProvider)),
);
final reportsRepositoryProvider = Provider<ReportsRepository>(
  (ref) => ReportsRepositoryImpl(ref.watch(reportsDaoProvider)),
);

final dashboardDaoProvider = Provider<DashboardDao>(
  (ref) => DashboardDao(ref.watch(databaseServiceProvider)),
);
final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepositoryImpl(
    ref.watch(dashboardDaoProvider),
    ref.watch(databaseServiceProvider),
  ),
);
