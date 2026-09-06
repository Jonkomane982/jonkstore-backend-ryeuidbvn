import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';
import '../routing/app_router.dart';
import '../../database/database_service.dart';
import '../../database/migrations/migration_service.dart';
import 'package:go_router/go_router.dart';

/// Provider for the ApiClient.
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

/// Provider for the AppRouter.
final routerProvider = Provider<GoRouter>((ref) {
  return appRouter;
});

/// Provider for the MigrationService.
final migrationServiceProvider = Provider<MigrationService>((ref) {
  return MigrationService();
});

/// Provider for the DatabaseService.
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  final migrationService = ref.watch(migrationServiceProvider);
  return DatabaseService(migrationService);
});
