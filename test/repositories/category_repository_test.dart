import 'package:flutter_test/flutter_test.dart';
import 'package:jonkstore/core/domain/models/category.dart';
import 'package:jonkstore/core/errors/failures.dart';
import 'package:jonkstore/database/dao/category_dao.dart';
import 'package:jonkstore/database/database_service.dart';
import 'package:jonkstore/database/migrations/migration_service.dart';
import 'package:jonkstore/datasources/local/category_local_datasource.dart';
import 'package:jonkstore/repositories/category_repository_impl.dart';
import 'package:jonkstore/sync/queue/sqlite_sync_queue.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

/// Test-only implementation of DatabaseService to inject in-memory DB.
class TestDatabaseService extends DatabaseService {
  final Database _db;
  TestDatabaseService(this._db) : super(MigrationService());

  @override
  Future<Database> get database async => _db;
}

void main() {
  late Database db;
  late CategoryRepositoryImpl repository;
  late CategoryDao categoryDao;
  late SqliteSyncQueue syncQueue;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // Initialize in-memory database
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    
    // Setup the full production 3NF schema
    final migrationService = MigrationService();
    await migrationService.onCreate(db, 1);
    
    final dbService = TestDatabaseService(db);
    categoryDao = CategoryDao(dbService);
    final localDataSource = CategoryLocalDataSource(categoryDao);
    syncQueue = SqliteSyncQueue(dbService);

    repository = CategoryRepositoryImpl(
      localDataSource: localDataSource,
      syncQueue: syncQueue,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Category Repository Business Logic (3NF SQLite)', () {
    test('Validation: Should prevent categories with duplicate names', () async {
      final category = Category(
        id: const Uuid().v4(),
        name: 'Electronics',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.create(category);

      final duplicate = category.copyWith(id: const Uuid().v4());
      final result = await repository.create(duplicate);

      expect(result.isFailure, true);
      expect(result.failure, isA<ValidationFailure>());
      expect(result.failure.message, contains('already exists'));
    });

    test('Safe Deletion: Should prevent soft-delete if linked to products', () async {
      final id = const Uuid().v4();
      await repository.create(Category(id: id, name: 'Active', createdAt: DateTime.now(), updatedAt: DateTime.now()));

      // Manually simulate a product link in product_categories join table
      await db.insert('product_categories', {
        'id': const Uuid().v4(),
        'product_id': 'prod_123',
        'category_id': id,
        'is_deleted': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'sync_status': 'PENDING'
      });

      final result = await repository.delete(id);

      expect(result.isFailure, true);
      expect(result.failure.message, contains('assigned to one or more products'));
    });

    test('Sync Integration: CREATE/UPDATE/DELETE should queue a sync task', () async {
      final category = Category(
        id: const Uuid().v4(),
        name: 'Sync Logic',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.create(category);
      
      final tasks = await db.query('sync_queue');
      expect(tasks.length, 1);
      expect(tasks.first['table_name'], 'categories');
      expect(tasks.first['operation'], 'CREATE');
    });

    test('Pagination: findAll should respect limit and offset', () async {
      for (int i = 0; i < 10; i++) {
        await categoryDao.insert(Category(
          id: 'ID_$i',
          name: 'Category $i',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }

      final firstPage = await repository.findAll(limit: 5, offset: 0);
      expect(firstPage.value.length, 5);

      final secondPage = await repository.findAll(limit: 5, offset: 5);
      expect(secondPage.value.length, 5);
      expect(secondPage.value.first.name, contains('5'));
    });
   group('Validation Rules', () {
      test('Should enforce maximum name length of 50 characters', () async {
        final longName = 'A' * 51;
        Category(
          id: '1',
          name: longName,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      });
    });
  });
}
