import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jonkstore/core/auth/permission_provider.dart';
import 'package:jonkstore/core/services/inventory_service.dart';
import 'package:jonkstore/core/services/inventory_calculation_service.dart';
import 'package:jonkstore/providers/repository_providers.dart';

/// Provider for the Inventory Calculation Service.
final inventoryCalculationServiceProvider = Provider<InventoryCalculationService>((ref) {
  return InventoryCalculationService();
});

/// Provider for the Business-logic Inventory Service.
final inventoryServiceProvider = Provider<InventoryService>((ref) {
  return InventoryService(
    ref.watch(inventoryRepositoryProvider),
    ref.watch(productRepositoryProvider),
    ref.watch(authorizationServiceProvider),
  );
});
