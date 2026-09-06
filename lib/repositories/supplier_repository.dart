import '../core/domain/models/supplier.dart';
import '../core/network/result.dart';

/// Interface for Supplier repository operations.
///
/// All mutations return the written record (with updated version/sync metadata)
/// so callers can immediately reflect the change in the UI without re-fetching.
abstract class SupplierRepository {
  /// Creates a new supplier and queues a CREATE sync task.
  ///
  /// Prevents duplicate names and duplicate codes, auto-assigns a UUID and code
  /// if none are supplied, stamps sync metadata, and validates required fields.
  Future<Result<Supplier>> create(Supplier supplier);

  /// Updates an existing supplier and queues an UPDATE sync task.
  Future<Result<Supplier>> update(Supplier supplier);

  /// Activates or deactivates a supplier without soft-deleting it.
  Future<Result<Supplier>> setActive(String id, bool isActive);

  /// Soft-deletes a supplier if it passes safe-deletion checks, queues DELETE.
  Future<Result<bool>> delete(String id);

  /// Restores a soft-deleted supplier.
  Future<Result<bool>> restore(String id);

  Future<Result<Supplier?>> findById(String id);

  /// Database-backed search, sort, filter, pagination.
  Future<Result<List<Supplier>>> findAll({
    String? searchQuery,
    String? sortBy,
    bool ascending,
    bool? isActive,
    int? limit,
    int? offset,
    bool includeDeleted,
  });

  /// Stream of supplier lists for real-time UI updates via broadcast controller.
  Stream<List<Supplier>> watchAll({bool includeDeleted = false});

  Future<Result<int>> count({
    String? searchQuery,
    bool? isActive,
    bool includeDeleted = false,
  });

  // ---- Supplier Detail aggregate queries ----
  Future<Result<int>> countProductsForSupplier(String supplierId);
  Future<Result<Map<String, double>>> getPurchaseTotals(String supplierId);
  Future<Result<List<Map<String, dynamic>>>> getRecentPurchases(
    String supplierId, {
    int limit,
  });

  Future<Result<void>> sync();
}
