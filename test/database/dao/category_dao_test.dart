import 'package:flutter_test/flutter_test.dart';
import 'package:jonkstore/core/domain/models/category.dart';
import 'package:jonkstore/database/dao/category_dao.dart';
import 'package:jonkstore/database/database_service.dart';
import 'package:jonkstore/database/migrations/migration_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

/// A test-only implementation of DatabaseService that uses an in-memory database.
class TestDatabaseService extends DatabaseService {
  final Database _db;
  TestDatabaseService(this._db) : super(MigrationService());

  @override
  Future<Database> get database async => _db;
}

void main() {
  late Database db;
  late CategoryDao categoryDao;
  late TestDatabaseService testDatabaseService;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // 1. Initialize in-memory database
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    
    // 2. Setup the full production schema
    final migrationService = MigrationService();
    await migrationService.onCreate(db, 1);
    
    // 3. Setup DAO with the test database service
    testDatabaseService = TestDatabaseService(db);
    categoryDao = CategoryDao(testDatabaseService);
  });

  tearDown(() async {
    await db.close();
  });

  group('CategoryDao Production Tests', () {
    test('Insert and findById should persist audit and sync fields correctly', () async {
      final category = Category(
        id: const Uuid().v4(),
        name: 'Beverages',
        description: 'Drinks and Sodas',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await categoryDao.insert(category);
      
      final found = await categoryDao.findById(category.id);
      
      expect(found, isNotNull);
      expect(found!.name, 'Beverages');
      expect(found.description, 'Drinks and Sodas');
      expect(found.isDeleted, false);
    });

    test('isCategoryInUse should return true when linked to a product', () async {
      final categoryId = const Uuid().v4();
      final productId = const Uuid().v4();
      
      // Seed category
      await db.insert('categories', {
        'id': categoryId,
        'name': 'In Use',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'is_deleted': 0,
        'sync_status': 'PENDING'
      });

      // Verification 1: Not in use
      expect(await categoryDao.isCategoryInUse(categoryId), false);

      // Seed product_category link
      await db.insert('product_categories', {
        'id': const Uuid().v4(),
        'product_id': productId,
        'category_id': categoryId,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'is_deleted': 0,
        'sync_status': 'PENDING'
      });

      // Verification 2: Now in use
      expect(await categoryDao.isCategoryInUse(categoryId), true);
    });

    test('findAll should filter by search query and exclude soft-deleted by default', () async {
      final cat1 = Category(id: '1', name: 'Snacks', createdAt: DateTime.now(), updatedAt: DateTime.now());
      final cat2 = Category(id: '2', name: 'Bread', createdAt: DateTime.now(), updatedAt: DateTime.now());
      
      await categoryDao.insert(cat1);
      await categoryDao.insert(cat2);
      
      // Soft delete 'Bread'
      await categoryDao.softDelete('2', 'tester');

      // Search for 'Snacks'
      final searchResult = await categoryDao.findAll(searchQuery: 'sna');
      expect(searchResult.length, 1);
      expect(searchResult.first.name, 'Snacks');

      // Default findAll should not see deleted 'Bread'
      final allActive = await categoryDao.findAll();
      expect(allActive.length, 1);
      expect(allActive.any((c) => c.name == 'Bread'), false);
    });

    test('Sorting should follow ascending/descending parameters', () async {
      await categoryDao.insert(Category(id: 'A', name: 'Apple', createdAt: DateTime.now(), updatedAt: DateTime.now()));
      await categoryDao.insert(Category(id: 'B', name: 'Zebra', createdAt: DateTime.now(), updatedAt: DateTime.now()));

      final asc = await categoryDao.findAll(sortBy: 'name', ascending: true);
      expect(asc.first.name, 'Apple');

      final desc = await categoryDao.findAll(sortBy: 'name', ascending: false);
      expect(desc.first.name, 'Zebra');
    });

    test('restore should return category to active state', () async {
      final id = const Uuid().v4();
      await categoryDao.insert(Category(id: id, name: 'Archive', createdAt: DateTime.now(), updatedAt: DateTime.now()));
      
      await categoryDao.softDelete(id, 'user_1');
      expect((await categoryDao.findById(id))!.isDeleted, true);

      await categoryDao.restore(id, 'user_1');
      final restored = await categoryDao.findById(id);
      expect(restored!.isDeleted, false);
      expect(restored.deletedAt, isNull);
    });
  });
}
