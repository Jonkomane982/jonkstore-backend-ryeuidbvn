import '../core/domain/models/category.dart';
import '../core/network/result.dart';

/// Interface for Category repository operations.
/// Supports advanced business features like search, sorting, and pagination.
abstract class CategoryRepository {
  /// Creates a new category and queues a sync task.
  Future<Result<Category>> create(Category category);

  /// Updates an existing category and queues a sync task.
  Future<Result<Category>> update(Category category);

  /// Soft deletes a category and queues a sync task.
  Future<Result<bool>> delete(String id);

  /// Restores a soft-deleted category and queues a sync task.
  Future<Result<bool>> restore(String id);

  /// Finds a specific category by ID.
  Future<Result<Category?>> findById(String id);

  /// Finds categories based on search, sort and pagination parameters.
  Future<Result<List<Category>>> findAll({
    String? searchQuery,
    String? sortBy,
    bool ascending = true,
    int? limit,
    int? offset,
    bool includeDeleted = false,
  });

  /// Returns a stream of category lists for real-time UI updates.
  Stream<List<Category>> watchAll({bool includeDeleted = false});

  /// Counts categories matching the criteria.
  Future<Result<int>> count({bool includeDeleted = false});

  /// Triggers a manual synchronization with the cloud.
  Future<Result<void>> sync();
}
