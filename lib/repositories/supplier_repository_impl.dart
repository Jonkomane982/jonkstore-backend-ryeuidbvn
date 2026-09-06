import 'dart:async';
import 'package:uuid/uuid.dart';
import '../core/domain/models/supplier.dart';
import '../core/domain/enums/sync_status.dart';
import '../core/network/result.dart';
import '../core/errors/failures.dart';
import '../datasources/local/supplier_local_datasource.dart';
import '../datasources/remote/supplier_remote_datasource.dart';
import '../sync/mixins/syncable_repository_mixin.dart';
import '../sync/queue/sync_queue.dart';
import 'supplier_repository.dart';

/// Production implementation of [SupplierRepository] using SQLite + SyncEngine.
///
/// All mutations:
///   1. Validate required fields + email/phone format + de-duplicate name/code.
///   2. Write transactionally to the local SQLite `suppliers` table.
///   3. Bump `sync_status` so SyncEngine knows the row is dirty.
///   4. Enqueue a SyncTask via [SyncableRepositoryMixin] for the engine to
///      process later when the backend is reachable.
///
/// Offline-first: never requires network for CRUD.  RemoteDataSource is
/// injected but currently not used in the happy path (reserved for SyncEngine
/// backfill operations).
class SupplierRepositoryImpl
    with SyncableRepositoryMixin
    implements SupplierRepository {
  final SupplierLocalDataSource localDataSource;
  final SupplierRemoteDataSource remoteDataSource;

  @override
  final SyncQueue syncQueue;

  @override
  String get entityName => 'suppliers';

  final _streamController = StreamController<List<Supplier>>.broadcast();

  SupplierRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
    required this.syncQueue,
  });

  // ---------------------------------------------------------------------------
  // Validation helpers
  // ---------------------------------------------------------------------------

  static String? trimOrNull(String? value) {
    if (value == null) return null;
    final t = value.trim();
    return t.isEmpty ? null : t;
  }

  static ValidationFailure? validateEmailFormat(String? email) {
    final e = trimOrNull(email);
    if (e == null) return null;
    final regex = RegExp(r'^[\w-\.+]+@([\w-]+\.)+[\w-]{2,}$');
    if (!regex.hasMatch(e)) {
      return const ValidationFailure('Enter a valid email address.');
    }
    return null;
  }

  static ValidationFailure? validatePhoneFormat(String? phone) {
    final p = trimOrNull(phone);
    if (p == null) return null;
    final regex = RegExp(r'^\+?[\d\s\-().]{7,}$');
    if (!regex.hasMatch(p)) {
      return const ValidationFailure('Enter a valid phone number.');
    }
    return null;
  }

  static double parseDoubleOrZero(String? v, {double fallback = 0}) {
    if (v == null || v.trim().isEmpty) return fallback;
    return double.tryParse(v.trim()) ?? fallback;
  }

  // ---------------------------------------------------------------------------
  // Create
  // ---------------------------------------------------------------------------

  @override
  Future<Result<Supplier>> create(Supplier supplier) async {
    try {
      final name = trimOrNull(supplier.name);
      if (name == null) {
        return Result.failure(
          const ValidationFailure('Supplier name is required.'),
        );
      }

      final emailFail = validateEmailFormat(supplier.email);
      if (emailFail != null) return Result.failure(emailFail);

      final phoneFail = validatePhoneFormat(supplier.phone);
      if (phoneFail != null) return Result.failure(phoneFail);

      final byName = await localDataSource.findByName(name);
      if (byName != null) {
        return Result.failure(
          const ValidationFailure('A supplier with this name already exists.'),
        );
      }

      final String suppliedCode =
          trimOrNull(supplier.code) ?? _generateSupplierCode();
      final byCode = await localDataSource.findByCode(suppliedCode);
      if (byCode != null) {
        return Result.failure(
          const ValidationFailure('A supplier with this code already exists.'),
        );
      }

      final now = DateTime.now();
      final who = supplier.createdBy ?? supplier.updatedBy;
      final prepared = Supplier(
        id: trimOrNull(supplier.id) ?? const Uuid().v4(),
        businessId: trimOrNull(supplier.businessId),
        name: name,
        code: suppliedCode,
        taxId: trimOrNull(supplier.taxId),
        website: trimOrNull(supplier.website),
        email: trimOrNull(supplier.email),
        phone: trimOrNull(supplier.phone),
        address: trimOrNull(supplier.address),
        city: trimOrNull(supplier.city),
        state: trimOrNull(supplier.state),
        country: trimOrNull(supplier.country),
        postalCode: trimOrNull(supplier.postalCode),
        contactName: trimOrNull(supplier.contactName),
        paymentTerms: trimOrNull(supplier.paymentTerms),
        creditLimit: supplier.creditLimit >= 0 ? supplier.creditLimit : 0,
        currentBalance: supplier.currentBalance,
        notes: trimOrNull(supplier.notes),
        isActive: supplier.isActive,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
        isDeleted: false,
        syncStatus: SyncStatus.pending,
        version: 1,
        createdBy: who,
        updatedBy: who,
      );

      await localDataSource.insert(prepared);
      await enqueueSyncTask(
        entityId: prepared.id,
        operation: 'CREATE',
        data: prepared.toJson(),
      );

      _refresh();
      return Result.success(prepared);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  // ---------------------------------------------------------------------------
  // Update
  // ---------------------------------------------------------------------------

  @override
  Future<Result<Supplier>> update(Supplier supplier) async {
    try {
      final existing = await localDataSource.findById(supplier.id);
      if (existing == null) {
        return Result.failure(const DatabaseFailure('Supplier not found.'));
      }

      final name = trimOrNull(supplier.name);
      if (name == null) {
        return Result.failure(
          const ValidationFailure('Supplier name is required.'),
        );
      }

      final emailFail = validateEmailFormat(supplier.email);
      if (emailFail != null) return Result.failure(emailFail);

      final phoneFail = validatePhoneFormat(supplier.phone);
      if (phoneFail != null) return Result.failure(phoneFail);

      final byName = await localDataSource.findByName(
        name,
        excludeId: supplier.id,
      );
      if (byName != null) {
        return Result.failure(
          const ValidationFailure('Another supplier already uses this name.'),
        );
      }

      final code = trimOrNull(supplier.code) ?? existing.code;
      final byCode = await localDataSource.findByCode(
        code,
        excludeId: supplier.id,
      );
      if (byCode != null) {
        return Result.failure(
          const ValidationFailure('Another supplier already uses this code.'),
        );
      }

      final who =
          supplier.updatedBy ??
          existing.updatedBy ??
          existing.createdBy ??
          'system';

      final prepared = existing.copyWith(
        name: name,
        code: code,
        taxId: trimOrNull(supplier.taxId) ?? existing.taxId,
        website: trimOrNull(supplier.website) ?? existing.website,
        email: trimOrNull(supplier.email) ?? existing.email,
        phone: trimOrNull(supplier.phone) ?? existing.phone,
        address: trimOrNull(supplier.address) ?? existing.address,
        city: trimOrNull(supplier.city) ?? existing.city,
        state: trimOrNull(supplier.state) ?? existing.state,
        country: trimOrNull(supplier.country) ?? existing.country,
        postalCode: trimOrNull(supplier.postalCode) ?? existing.postalCode,
        contactName: trimOrNull(supplier.contactName) ?? existing.contactName,
        paymentTerms:
            trimOrNull(supplier.paymentTerms) ?? existing.paymentTerms,
        creditLimit: supplier.creditLimit >= 0 ? supplier.creditLimit : 0,
        currentBalance: supplier.currentBalance,
        notes: trimOrNull(supplier.notes) ?? existing.notes,
        isActive: supplier.isActive,
        updatedAt: DateTime.now(),
        updatedBy: who,
        syncStatus: SyncStatus.updated,
        version: existing.version + 1,
      );

      await localDataSource.update(prepared);
      await enqueueSyncTask(
        entityId: prepared.id,
        operation: 'UPDATE',
        data: prepared.toJson(),
      );

      _refresh();
      return Result.success(prepared);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  // ---------------------------------------------------------------------------
  // Activate / Deactivate
  // ---------------------------------------------------------------------------

  @override
  Future<Result<Supplier>> setActive(String id, bool isActive) async {
    try {
      final existing = await localDataSource.findById(id);
      if (existing == null) {
        return Result.failure(const DatabaseFailure('Supplier not found.'));
      }
      final who = existing.updatedBy ?? existing.createdBy ?? 'system';
      await localDataSource.setActive(id, isActive, who);
      final refreshed = existing.copyWith(
        isActive: isActive,
        updatedAt: DateTime.now(),
        updatedBy: who,
        syncStatus: SyncStatus.updated,
        version: existing.version + 1,
      );
      await enqueueSyncTask(
        entityId: id,
        operation: 'UPDATE',
        data: refreshed.toJson(),
      );
      _refresh();
      return Result.success(refreshed);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  // ---------------------------------------------------------------------------
  // Soft delete / restore
  // ---------------------------------------------------------------------------

  @override
  Future<Result<bool>> delete(String id) async {
    try {
      final inUse = await localDataSource.isSupplierInUse(id);
      if (inUse) {
        return Result.failure(
          const ValidationFailure(
            'Cannot delete supplier. It is referenced by products or purchase records. '
            'Deactivate it instead or remove the references first.',
          ),
        );
      }

      final existing = await localDataSource.findById(id);
      if (existing == null) return Result.success(true);
      final who = existing.updatedBy ?? existing.createdBy ?? 'system';

      await localDataSource.softDelete(id, who);
      final deleted = existing.copyWith(
        isDeleted: true,
        deletedAt: DateTime.now(),
        updatedAt: DateTime.now(),
        updatedBy: who,
        syncStatus: SyncStatus.deleted,
        version: existing.version + 1,
      );
      await enqueueSyncTask(
        entityId: id,
        operation: 'DELETE',
        data: deleted.toJson(),
      );

      _refresh();
      return Result.success(true);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<bool>> restore(String id) async {
    try {
      final existing = await localDataSource.findById(id);
      if (existing == null) {
        return Result.failure(const DatabaseFailure('Supplier not found.'));
      }
      final who = existing.updatedBy ?? existing.createdBy ?? 'system';
      await localDataSource.restore(id, who);
      final restored = existing.copyWith(
        isDeleted: false,
        deletedAt: null,
        updatedAt: DateTime.now(),
        updatedBy: who,
        syncStatus: SyncStatus.updated,
        version: existing.version + 1,
      );
      await enqueueSyncTask(
        entityId: id,
        operation: 'UPDATE',
        data: restored.toJson(),
      );
      _refresh();
      return Result.success(true);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  // ---------------------------------------------------------------------------
  // Read queries
  // ---------------------------------------------------------------------------

  @override
  Future<Result<Supplier?>> findById(String id) async {
    try {
      return Result.success(await localDataSource.findById(id));
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<Supplier>>> findAll({
    String? searchQuery,
    String? sortBy,
    bool ascending = true,
    bool? isActive,
    int? limit,
    int? offset,
    bool includeDeleted = false,
  }) async {
    try {
      final suppliers = await localDataSource.findAll(
        searchQuery: searchQuery,
        sortBy: sortBy,
        ascending: ascending,
        isActive: isActive,
        limit: limit,
        offset: offset,
        includeDeleted: includeDeleted,
      );
      return Result.success(suppliers);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Stream<List<Supplier>> watchAll({bool includeDeleted = false}) {
    _refresh(includeDeleted: includeDeleted);
    return _streamController.stream;
  }

  @override
  Future<Result<int>> count({
    String? searchQuery,
    bool? isActive,
    bool includeDeleted = false,
  }) async {
    try {
      return Result.success(
        await localDataSource.count(
          searchQuery: searchQuery,
          isActive: isActive,
          includeDeleted: includeDeleted,
        ),
      );
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  // ---------------------------------------------------------------------------
  // Supplier detail aggregate queries
  // ---------------------------------------------------------------------------

  @override
  Future<Result<int>> countProductsForSupplier(String supplierId) async {
    try {
      return Result.success(
        await localDataSource.countProductsForSupplier(supplierId),
      );
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<Map<String, double>>> getPurchaseTotals(
    String supplierId,
  ) async {
    try {
      return Result.success(
        await localDataSource.getPurchaseTotals(supplierId),
      );
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getRecentPurchases(
    String supplierId, {
    int limit = 10,
  }) async {
    try {
      return Result.success(
        await localDataSource.getRecentPurchases(supplierId, limit: limit),
      );
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  // ---------------------------------------------------------------------------
  // Sync (handled by SyncEngine)
  // ---------------------------------------------------------------------------

  @override
  Future<Result<void>> sync() async {
    return Result.success(null);
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  static String _generateSupplierCode() {
    final rnd = DateTime.now().microsecondsSinceEpoch.remainder(1000000);
    return 'SUP-${rnd.toString().padLeft(6, '0')}';
  }

  void _refresh({bool includeDeleted = false}) async {
    final res = await findAll(includeDeleted: includeDeleted);
    res.fold(
      (list) => _streamController.add(list),
      (failure) => _streamController.addError(failure),
    );
  }
}
