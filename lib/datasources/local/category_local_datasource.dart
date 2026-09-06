import '../../database/dao/category_dao.dart';
import '../../core/domain/models/category.dart';

/// Local data source for Category operations.
/// Acts as a bridge between the repository and the DAO.
class CategoryLocalDataSource {
  final CategoryDao _categoryDao;

  CategoryLocalDataSource(this._categoryDao);

  Future<void> insert(Category category) async {
    await _categoryDao.insert(category);
  }

  Future<void> update(Category category) async {
    await _categoryDao.update(category);
  }

  Future<bool> isCategoryInUse(String categoryId) async {
    return await _categoryDao.isCategoryInUse(categoryId);
  }

  Future<void> softDelete(String id, String userId) async {
    await _categoryDao.softDelete(id, userId);
  }

  Future<void> restore(String id, String userId) async {
    await _categoryDao.restore(id, userId);
  }

  Future<Category?> findById(String id) async {
    return await _categoryDao.findById(id);
  }

  Future<Category?> findByName(String name, {String? excludeId}) async {
    return await _categoryDao.findByName(name, excludeId: excludeId);
  }

  Future<List<Category>> findAll({
    String? searchQuery,
    String? sortBy,
    bool ascending = true,
    int? limit,
    int? offset,
    bool includeDeleted = false,
  }) async {
    return await _categoryDao.findAll(
      searchQuery: searchQuery,
      sortBy: sortBy,
      ascending: ascending,
      limit: limit,
      offset: offset,
      includeDeleted: includeDeleted,
    );
  }

  Future<int> count({bool includeDeleted = false}) async {
    return await _categoryDao.count(includeDeleted: includeDeleted);
  }
}
