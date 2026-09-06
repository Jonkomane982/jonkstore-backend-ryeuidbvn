import 'package:flutter_test/flutter_test.dart';
import 'package:jonkstore/core/domain/models/supplier.dart';
import 'package:jonkstore/database/dao/supplier_dao.dart';
import 'package:jonkstore/database/database_service.dart';
import 'package:jonkstore/database/migrations/migration_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

class TestDatabaseService extends DatabaseService {
  final Database _db;
  TestDatabaseService(this._db) : super(MigrationService());

  @override
  Future<Database> get database async => _db;
}

void main() {
  late Database db;
  late SupplierDao supplierDao;
  late TestDatabaseService testDatabaseService;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    final migrationService = MigrationService();
    await migrationService.onCreate(db, 1);
    testDatabaseService = TestDatabaseService(db);
    supplierDao = SupplierDao(testDatabaseService);
  });

  tearDown(() async {
    await db.close();
  });

  group('SupplierDao Insert / Find', () {
    test('insert and findById persist all 3NF fields correctly', () async {
      final now = DateTime.now();
      final supplier = Supplier(
        id: const Uuid().v4(),
        businessId: 'biz_test',
        name: 'Acme Supplies',
        code: 'SUP-001',
        taxId: 'PIN-TEST',
        website: 'https://acme.test',
        email: 'contact@acme.test',
        phone: '+254700000001',
        address: '1 Test Rd',
        city: 'Nairobi',
        state: 'Nairobi',
        country: 'Kenya',
        postalCode: '00100',
        contactName: 'John Doe',
        paymentTerms: 'Net 30',
        creditLimit: 100000,
        currentBalance: 5000.25,
        notes: 'Test note',
        isActive: true,
        createdAt: now,
        updatedAt: now,
        version: 1,
        createdBy: 'tester',
        updatedBy: 'tester',
      );

      await supplierDao.insert(supplier);
      final found = await supplierDao.findById(supplier.id);

      expect(found, isNotNull);
      expect(found!.name, 'Acme Supplies');
      expect(found.code, 'SUP-001');
      expect(found.taxId, 'PIN-TEST');
      expect(found.website, 'https://acme.test');
      expect(found.email, 'contact@acme.test');
      expect(found.phone, '+254700000001');
      expect(found.address, '1 Test Rd');
      expect(found.city, 'Nairobi');
      expect(found.state, 'Nairobi');
      expect(found.country, 'Kenya');
      expect(found.postalCode, '00100');
      expect(found.contactName, 'John Doe');
      expect(found.paymentTerms, 'Net 30');
      expect(found.creditLimit, 100000);
      expect(found.currentBalance, 5000.25);
      expect(found.notes, 'Test note');
      expect(found.isActive, true);
      expect(found.isDeleted, false);
      expect(found.version, 1);
    });

    test('findByName and findByCode exclude deleted records', () async {
      final s1 = Supplier(
        id: '1',
        name: 'UniqueName',
        code: 'UNIQUE-1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final s2 = Supplier(
        id: '2',
        name: 'DeletedName',
        code: 'DELETED-1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await supplierDao.insert(s1);
      await supplierDao.insert(s2);
      await supplierDao.softDelete('2', 'tester');

      expect((await supplierDao.findByName('UniqueName'))!.id, '1');
      expect(await supplierDao.findByName('DeletedName'), isNull);

      expect((await supplierDao.findByCode('UNIQUE-1'))!.id, '1');
      expect(await supplierDao.findByCode('DELETED-1'), isNull);
    });

    test('findByName/findByCode support excludeId for updates', () async {
      final a = Supplier(id: 'a', name: 'Alpha', code: 'A', createdAt: DateTime.now(), updatedAt: DateTime.now());
      final b = Supplier(id: 'b', name: 'Beta', code: 'B', createdAt: DateTime.now(), updatedAt: DateTime.now());
      await supplierDao.insert(a);
      await supplierDao.insert(b);

      expect(await supplierDao.findByName('Alpha', excludeId: 'a'), isNull);
      expect(await supplierDao.findByName('Beta', excludeId: 'a'), isNotNull);
      expect(await supplierDao.findByCode('A', excludeId: 'a'), isNull);
    });
  });

  group('SupplierDao Search, Filter, Sort', () {
    setUp(() async {
      final now = DateTime.now();
      await supplierDao.insert(Supplier(
        id: 's1',
        name: 'Acme Foods',
        code: 'SUP-FOOD',
        contactName: 'Alice',
        phone: '+254711111111',
        isActive: true,
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now.subtract(const Duration(days: 5)),
      ));
      await supplierDao.insert(Supplier(
        id: 's2',
        name: 'Zenith Hardware',
        code: 'SUP-HW',
        contactName: 'Bob',
        phone: '+254722222222',
        isActive: false,
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ));
      await supplierDao.insert(Supplier(
        id: 's3',
        name: 'Acme Tools',
        code: 'SUP-TOOLS',
        contactName: 'Carol',
        phone: '+254733333333',
        isActive: true,
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: now.subtract(const Duration(days: 10)),
      ));
    });

    test('findAll searches by name, code, contactName, phone', () async {
      expect((await supplierDao.findAll(searchQuery: 'Acme')).length, 2);
      expect((await supplierDao.findAll(searchQuery: 'SUP-HW')).length, 1);
      expect((await supplierDao.findAll(searchQuery: 'Bob')).length, 1);
      expect((await supplierDao.findAll(searchQuery: '222222')).first.id, 's2');
      expect((await supplierDao.findAll(searchQuery: 'doesnotexist')), isEmpty);
    });

    test('findAll filters by isActive', () async {
      final active = await supplierDao.findAll(isActive: true);
      final inactive = await supplierDao.findAll(isActive: false);
      expect(active.length, 2);
      expect(active.every((s) => s.isActive), true);
      expect(inactive.length, 1);
      expect(inactive.first.id, 's2');
    });

    test('findAll sorts name asc/desc correctly', () async {
      final asc = await supplierDao.findAll(sortBy: 'name', ascending: true);
      final desc = await supplierDao.findAll(sortBy: 'name', ascending: false);
      expect(asc.first.name, 'Acme Foods');
      expect(asc.last.name, 'Zenith Hardware');
      expect(desc.first.name, 'Zenith Hardware');
      expect(desc.last.name, 'Acme Foods');
    });

    test('findAll sorts by created_at', () async {
      final r = await supplierDao.findAll(sortBy: 'created_at', ascending: false);
      expect(r.first.id, 's2');
      expect(r.last.id, 's3');
    });

    test('count respects search and active filters', () async {
      expect(await supplierDao.count(), 3);
      expect(await supplierDao.count(searchQuery: 'Acme'), 2);
      expect(await supplierDao.count(isActive: false), 1);
    });

    test('findAll exclude deleted by default', () async {
      await supplierDao.softDelete('s1', 'tester');
      final all = await supplierDao.findAll();
      expect(all.length, 2);
      expect(all.any((s) => s.id == 's1'), false);
      final withDeleted = await supplierDao.findAll(includeDeleted: true);
      expect(withDeleted.length, 3);
    });

    test('pagination limit/offset works', () async {
      final page1 = await supplierDao.findAll(limit: 2, offset: 0, sortBy: 'name');
      final page2 = await supplierDao.findAll(limit: 2, offset: 2, sortBy: 'name');
      expect(page1.length, 2);
      expect(page2.length, 1);
    });
  });

  group('SupplierDao Soft Delete / Restore / Activate', () {
    test('softDelete sets isDeleted/deletedAt, restore clears them', () async {
      final s = Supplier(id: 'd1', name: 'D1', code: 'D1', createdAt: DateTime.now(), updatedAt: DateTime.now());
      await supplierDao.insert(s);
      expect((await supplierDao.findById('d1'))!.isDeleted, false);

      await supplierDao.softDelete('d1', 'u1');
      final deleted = await supplierDao.findById('d1');
      expect(deleted!.isDeleted, true);
      expect(deleted.deletedAt, isNotNull);
      expect(deleted.updatedBy, 'u1');

      await supplierDao.restore('d1', 'u2');
      final restored = await supplierDao.findById('d1');
      expect(restored!.isDeleted, false);
      expect(restored.deletedAt, isNull);
      expect(restored.updatedBy, 'u2');
    });

    test('setActive toggles flag and stamps updatedBy', () async {
      final s = Supplier(id: 'a1', name: 'A1', code: 'A1', createdAt: DateTime.now(), updatedAt: DateTime.now(), isActive: true);
      await supplierDao.insert(s);

      await supplierDao.setActive('a1', false, 'op1');
      expect((await supplierDao.findById('a1'))!.isActive, false);
      await supplierDao.setActive('a1', true, 'op2');
      final f = await supplierDao.findById('a1');
      expect(f!.isActive, true);
      expect(f.updatedBy, 'op2');
    });
  });

  group('SupplierDao Safe Deletion / Aggregates', () {
    test('isSupplierInUse returns true when a product references it', () async {
      final supplierId = const Uuid().v4();
      await supplierDao.insert(Supplier(
        id: supplierId,
        name: 'Linked',
        code: 'LNK',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      expect(await supplierDao.isSupplierInUse(supplierId), false);

      final cols = await db.rawQuery('PRAGMA table_info(products)');
      final hasFk = cols.any((row) => row['name'].toString().toLowerCase() == 'supplier_id');
      if (hasFk) {
        final productId = const Uuid().v4();
        await db.insert('products', {
          'id': productId,
          'name': 'Test Item',
          'business_id': 'biz1',
          'category_id': 'cat1',
          'price': 10.0,
          'supplier_id': supplierId,
          'track_inventory': 1,
          'is_active': 1,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'is_deleted': 0,
          'sync_status': 'PENDING',
        });
        expect(await supplierDao.isSupplierInUse(supplierId), true);
      }
    });

    test('Purchase totals return zero when no POs', () async {
      final id = const Uuid().v4();
      final totals = await supplierDao.getPurchaseTotals(id);
      expect(totals['total_purchase_value'], 0);
      expect(totals['outstanding_balance'], 0);
      expect(totals['purchase_count'], 0);
    });

    test('Recent purchases empty for new supplier', () async {
      final id = const Uuid().v4();
      expect(await supplierDao.getRecentPurchases(id, limit: 5), isEmpty);
    });

    test('countProductsForSupplier returns 0 for unused supplier', () async {
      final id = const Uuid().v4();
      expect(await supplierDao.countProductsForSupplier(id), 0);
    });
  });
}
