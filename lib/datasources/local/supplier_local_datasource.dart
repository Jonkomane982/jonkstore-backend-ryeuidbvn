import '../../core/domain/models/supplier.dart';
import '../../database/dao/supplier_dao.dart';

/// Local data source for Supplier operations using SQLite DAO.
///
/// Acts as a bridge between the repository and the DAO so the repository
/// layer stays agnostic of the underlying persistence mechanism.
class SupplierLocalDataSource {
  final SupplierDao _dao;

  SupplierLocalDataSource(this._dao);

  Future<void> insert(Supplier supplier) => _dao.insert(supplier);
  Future<int> update(Supplier supplier) => _dao.update(supplier);
  Future<int> setActive(String id, bool isActive, String userId) =>
      _dao.setActive(id, isActive, userId);
  Future<void> softDelete(String id, String userId) =>
      _dao.softDelete(id, userId);
  Future<void> restore(String id, String userId) => _dao.restore(id, userId);

  Future<bool> isSupplierInUse(String supplierId) =>
      _dao.isSupplierInUse(supplierId);

  Future<Supplier?> findById(String id) => _dao.findById(id);
  Future<Supplier?> findByName(String name, {String? excludeId}) =>
      _dao.findByName(name, excludeId: excludeId);
  Future<Supplier?> findByCode(String code, {String? excludeId}) =>
      _dao.findByCode(code, excludeId: excludeId);

  Future<List<Supplier>> findAll({
    String? searchQuery,
    String? sortBy,
    bool ascending = true,
    bool? isActive,
    int? limit,
    int? offset,
    bool includeDeleted = false,
  }) {
    return _dao.findAll(
      searchQuery: searchQuery,
      sortBy: sortBy,
      ascending: ascending,
      isActive: isActive,
      limit: limit,
      offset: offset,
      includeDeleted: includeDeleted,
    );
  }

  Future<int> count({
    String? searchQuery,
    bool? isActive,
    bool includeDeleted = false,
  }) {
    return _dao.count(
      searchQuery: searchQuery,
      isActive: isActive,
      includeDeleted: includeDeleted,
    );
  }

  Future<int> countProductsForSupplier(String supplierId) =>
      _dao.countProductsForSupplier(supplierId);

  Future<Map<String, double>> getPurchaseTotals(String supplierId) =>
      _dao.getPurchaseTotals(supplierId);

  Future<List<Map<String, dynamic>>> getRecentPurchases(
    String supplierId, {
    int limit = 10,
  }) {
    return _dao.getRecentPurchases(supplierId, limit: limit);
  }
}
