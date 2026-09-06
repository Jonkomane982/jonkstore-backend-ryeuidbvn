import 'package:flutter_test/flutter_test.dart';
import 'package:jonkstore/core/domain/models/supplier.dart';
import 'package:jonkstore/core/domain/enums/sync_status.dart';
import 'package:jonkstore/core/errors/failures.dart';
import 'package:jonkstore/core/network/result.dart';
import 'package:jonkstore/core/network/api_client.dart';
import 'package:jonkstore/datasources/local/supplier_local_datasource.dart';
import 'package:jonkstore/datasources/remote/supplier_remote_datasource.dart';
import 'package:jonkstore/repositories/supplier_repository_impl.dart';
import 'package:jonkstore/sync/queue/sync_queue.dart';
import 'package:jonkstore/sync/models/sync_task.dart';
import 'package:jonkstore/sync/models/sync_state.dart';

// ===========================================================================
// Real test doubles (NOT mocks). Implement the production interfaces using
// in-memory storage so the tests exercise the real production contract
// without Mocktail `Mock` classes.
// ===========================================================================

class _InMemorySyncQueue implements SyncQueue {
  final List<SyncTask> tasks = [];

  @override
  Future<void> addTask(SyncTask task) async {
    tasks.add(task);
  }

  @override
  Future<List<SyncTask>> getPendingTasks() async =>
      tasks.where((t) => t.state == SyncState.pending).toList();

  @override
  Future<void> updateTaskState(
    String taskId,
    SyncState state, {
    String? error,
  }) async {
    final idx = tasks.indexWhere((t) => t.id == taskId);
    if (idx != -1) {
      tasks[idx] = tasks[idx].copyWith(state: state, lastError: error);
    }
  }

  @override
  Future<void> removeTask(String taskId) async {
    tasks.removeWhere((t) => t.id == taskId);
  }

  @override
  Future<List<SyncTask>> getFailedTasks() async =>
      tasks.where((t) => t.state == SyncState.failed).toList();

  @override
  Future<void> clear() async {
    tasks.clear();
  }
}

class _InMemorySupplierLocalDataSource implements SupplierLocalDataSource {
  final List<Supplier> table = [];

  @override
  Future<void> insert(Supplier supplier) async {
    table.add(supplier);
  }

  @override
  Future<int> update(Supplier supplier) async {
    final idx = table.indexWhere((s) => s.id == supplier.id);
    if (idx == -1) return 0;
    table[idx] = supplier;
    return 1;
  }

  @override
  Future<int> setActive(String id, bool isActive, String userId) async {
    final idx = table.indexWhere((s) => s.id == id);
    if (idx == -1) return 0;
    table[idx] = table[idx].copyWith(
      isActive: isActive,
      updatedAt: DateTime.now(),
      updatedBy: userId,
    );
    return 1;
  }

  @override
  Future<void> softDelete(String id, String userId) async {
    final idx = table.indexWhere((s) => s.id == id);
    if (idx != -1) {
      table[idx] = table[idx].copyWith(
        isDeleted: true,
        deletedAt: DateTime.now(),
        updatedAt: DateTime.now(),
        updatedBy: userId,
      );
    }
  }

  @override
  Future<void> restore(String id, String userId) async {
    final idx = table.indexWhere((s) => s.id == id);
    if (idx != -1) {
      table[idx] = table[idx].copyWith(
        isDeleted: false,
        deletedAt: null,
        updatedAt: DateTime.now(),
        updatedBy: userId,
      );
    }
  }

  @override
  Future<bool> isSupplierInUse(String supplierId) async {
    return table.any(
      (s) => s.id == supplierId && (s.notes ?? '').startsWith('INUSE'),
    );
  }

  @override
  Future<Supplier?> findById(String id) async {
    for (final s in table) {
      if (s.id == id) return s;
    }
    return null;
  }

  @override
  Future<Supplier?> findByName(String name, {String? excludeId}) async {
    final trimmed = name.trim().toLowerCase();
    for (final s in table) {
      if (s.name.trim().toLowerCase() == trimmed && s.id != excludeId) {
        return s;
      }
    }
    return null;
  }

  @override
  Future<Supplier?> findByCode(String code, {String? excludeId}) async {
    final upper = code.trim().toUpperCase();
    for (final s in table) {
      if (s.code.trim().toUpperCase() == upper && s.id != excludeId) {
        return s;
      }
    }
    return null;
  }

  @override
  Future<List<Supplier>> findAll({
    String? searchQuery,
    String? sortBy,
    bool ascending = true,
    bool? isActive,
    int? limit,
    int? offset,
    bool includeDeleted = false,
  }) async {
    List<Supplier> out = List.of(table);
    if (!includeDeleted) out = out.where((s) => !s.isDeleted).toList();
    if (isActive != null) {
      out = out.where((s) => s.isActive == isActive).toList();
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      out = out.where((s) {
        return s.name.toLowerCase().contains(q) ||
            s.code.toLowerCase().contains(q) ||
            (s.email ?? '').toLowerCase().contains(q) ||
            (s.phone ?? '').toLowerCase().contains(q) ||
            (s.city ?? '').toLowerCase().contains(q);
      }).toList();
    }
    final sortField = (sortBy ?? 'name').trim().toLowerCase();
    int dir = ascending ? 1 : -1;
    out.sort((a, b) {
      int cmp = 0;
      switch (sortField) {
        case 'code':
          cmp = a.code.compareTo(b.code);
          break;
        case 'created_at':
          cmp = a.createdAt.compareTo(b.createdAt);
          break;
        case 'updated_at':
          cmp = a.updatedAt.compareTo(b.updatedAt);
          break;
        case 'name':
        default:
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      return cmp * dir;
    });
    int off = offset ?? 0;
    int? lim = limit;
    if (off > out.length) return <Supplier>[];
    List<Supplier> sliced = out.sublist(off);
    if (lim != null && lim > 0 && sliced.length > lim) {
      sliced = sliced.sublist(0, lim);
    }
    return sliced;
  }

  @override
  Future<int> count({
    String? searchQuery,
    bool? isActive,
    bool includeDeleted = false,
  }) async {
    List<Supplier> out = List.of(table);
    if (!includeDeleted) out = out.where((s) => !s.isDeleted).toList();
    if (isActive != null) {
      out = out.where((s) => s.isActive == isActive).toList();
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      out = out.where((s) {
        return s.name.toLowerCase().contains(q) ||
            s.code.toLowerCase().contains(q);
      }).toList();
    }
    return out.length;
  }

  @override
  Future<int> countProductsForSupplier(String supplierId) async {
    final s = await findById(supplierId);
    if (s == null) return 0;
    final h = s.notes ?? '';
    final match = RegExp(r'PRODUCTS:(\d+)').firstMatch(h);
    if (match == null) return 0;
    return int.parse(match.group(1)!);
  }

  @override
  Future<Map<String, double>> getPurchaseTotals(String supplierId) async {
    final s = await findById(supplierId);
    if (s == null) return <String, double>{};
    return <String, double>{'total': s.creditLimit, 'paid': s.currentBalance};
  }

  @override
  Future<List<Map<String, dynamic>>> getRecentPurchases(
    String supplierId, {
    int limit = 10,
  }) async {
    final s = await findById(supplierId);
    if (s == null) return const <Map<String, dynamic>>[];
    final n = limit > 0 ? limit : 1;
    return List<Map<String, dynamic>>.generate(
      n > 2 ? 2 : n,
      (i) => <String, dynamic>{
        'id': 'PO-$supplierId-$i',
        'supplier_id': supplierId,
        'total': (i + 1) * 100.0,
        'created_at': DateTime.now()
            .subtract(Duration(days: i + 1))
            .toIso8601String(),
      },
    );
  }
}

class _NoopApiClient extends ApiClient {
  _NoopApiClient() : super(baseUrl: 'http://localhost');

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async => null;
  @override
  Future<dynamic> post(
    String path, {
    dynamic data,
    Map<String, String>? headers,
  }) async => {'data': null};
  @override
  Future<dynamic> put(
    String path, {
    dynamic data,
    Map<String, String>? headers,
  }) async => null;
  @override
  Future<dynamic> delete(
    String path, {
    dynamic data,
    Map<String, String>? headers,
  }) async => null;
}

SupplierRepositoryImpl _buildRepo(
  _InMemorySupplierLocalDataSource local,
  _InMemorySyncQueue queue,
) {
  final remote = SupplierRemoteDataSource(_NoopApiClient());
  return SupplierRepositoryImpl(
    localDataSource: local,
    remoteDataSource: remote,
    syncQueue: queue,
  );
}

Supplier baseSupplier({
  String id = 's1',
  String name = 'Test Supplier',
  String? code = 'TST-001',
  bool active = true,
  String? createdBy = 'user-1',
  String? updatedBy = 'user-1',
}) {
  final now = DateTime.now().toUtc();
  return Supplier(
    id: id,
    businessId: 'biz-1',
    name: name,
    code: code ?? '',
    isActive: active,
    createdAt: now,
    updatedAt: now,
    version: 1,
    createdBy: createdBy,
    updatedBy: updatedBy,
    syncStatus: SyncStatus.pending,
  );
}

void main() {
  late _InMemorySupplierLocalDataSource local;
  late _InMemorySyncQueue queue;
  late SupplierRepositoryImpl repo;

  setUp(() {
    local = _InMemorySupplierLocalDataSource();
    queue = _InMemorySyncQueue();
    repo = _buildRepo(local, queue);
  });

  group('SupplierRepositoryImpl - Create Validation', () {
    test('create rejects empty name with ValidationFailure', () async {
      final bad = baseSupplier(name: '   ');
      final res = await repo.create(bad);
      expect(res, isA<Result<Supplier>>());
      expect(res.isFailure, isTrue);
      res.fold((_) => fail('Expected failure'), (f) {
        expect(f, isA<ValidationFailure>());
        expect(f.message.toLowerCase(), contains('supplier name'));
      });
      expect(local.table.length, 0);
      expect(queue.tasks.length, 0);
    });

    test('create rejects invalid email format', () async {
      final s = baseSupplier(
        name: 'Valid Name',
      ).copyWith(email: 'not-an-email');
      final res = await repo.create(s);
      expect(res.isFailure, isTrue);
      res.fold((_) => fail('Should fail'), (f) {
        expect(f, isA<ValidationFailure>());
        expect(f.message.toLowerCase(), contains('email'));
      });
    });

    test('create rejects invalid phone format', () async {
      final s = baseSupplier(name: 'Valid Name').copyWith(phone: '1');
      final res = await repo.create(s);
      expect(res.isFailure, isTrue);
      res.fold((_) => fail('Should fail'), (f) {
        expect(f, isA<ValidationFailure>());
        expect(f.message.toLowerCase(), contains('phone'));
      });
    });

    test('create fails when name duplicate', () async {
      await local.insert(
        baseSupplier(id: 'dup1', name: 'Dup Supplier', code: 'DUP1'),
      );
      final res = await repo.create(
        baseSupplier(name: '   Dup Supplier  ', code: 'DUP2'),
      );
      expect(res.isFailure, isTrue);
      res.fold((_) => fail('Expected duplicate failure'), (f) {
        expect(f, isA<ValidationFailure>());
        expect(f.message.toLowerCase(), contains('name'));
      });
    });

    test('create fails when code duplicate', () async {
      await local.insert(
        baseSupplier(id: 'dup2', name: 'First Existing', code: 'DUPE'),
      );
      final res = await repo.create(
        baseSupplier(name: 'Unique Name', code: 'DUPE'),
      );
      expect(res.isFailure, isTrue);
      res.fold((_) => fail('Expected code conflict'), (f) {
        expect(f, isA<ValidationFailure>());
        expect(f.message.toLowerCase(), contains('code'));
      });
    });

    test('create succeeds: persists + enqueues CREATE sync task', () async {
      final s = baseSupplier(name: 'OK Supplier', code: 'OK-001').copyWith(
        email: 'support@example.com',
        phone: '+254711000000',
        notes: 'Hi',
        creditLimit: 2000,
      );
      final res = await repo.create(s);
      expect(res.isSuccess, isTrue);
      res.fold((created) {
        expect(created.name, 'OK Supplier');
        expect(created.isDeleted, false);
        expect(created.version, 1);
        expect(created.email, 'support@example.com');
        expect(created.phone, '+254711000000');
        expect(created.notes, 'Hi');
        expect(created.creditLimit, 2000);
        expect(created.syncStatus, SyncStatus.pending);
      }, (f) => fail('Expected success, got $f'));
      expect(local.table.length, 1);
      expect(queue.tasks.length, 1);
      expect(queue.tasks.first.operation, 'CREATE');
      expect(queue.tasks.first.entityName, 'suppliers');
    });

    test(
      'create auto-generates code in SUP-XXXXXX pattern when blank',
      () async {
        final res = await repo.create(
          baseSupplier(name: 'Code Auto', code: '  '),
        );
        expect(res.isSuccess, isTrue);
        res.fold((created) {
          expect(created.code, startsWith('SUP-'));
          expect(created.code.length, greaterThanOrEqualTo(10));
        }, (f) => fail('Unexpected failure $f'));
      },
    );
  });

  group('SupplierRepositoryImpl - Update', () {
    test(
      'update requires existing supplier; returns DatabaseFailure when not found',
      () async {
        final res = await repo.update(
          baseSupplier(id: 'missing', name: 'Nope'),
        );
        expect(res.isFailure, isTrue);
        res.fold(
          (_) => fail('Missing'),
          (f) => expect(f, isA<DatabaseFailure>()),
        );
        expect(queue.tasks.length, 0);
      },
    );

    test('update preserves fields not being updated from existing', () async {
      final existing = baseSupplier(id: 's1', name: 'Existing', code: 'EXIST')
          .copyWith(
            email: 'old@ex.com',
            phone: '+254700000000',
            notes: 'Old note',
            creditLimit: 1000,
          );
      await local.insert(existing);

      final update = baseSupplier(id: 's1', name: 'Renamed', code: 'EXIST');
      final res = await repo.update(update);
      expect(res.isSuccess, isTrue);
      res.fold((u) {
        expect(u.name, 'Renamed');
        expect(u.code, 'EXIST');
        expect(u.email, 'old@ex.com');
        expect(u.phone, '+254700000000');
        expect(u.notes, 'Old note');
        expect(u.creditLimit, 1000);
        expect(u.version, 2);
        expect(u.syncStatus, SyncStatus.updated);
      }, (f) => fail('Unexpected $f'));
      expect(queue.tasks.length, 1);
      expect(queue.tasks.first.operation, 'UPDATE');
    });

    test('update rejects name duplicate in another record', () async {
      await local.insert(baseSupplier(id: 's1', name: 'Alpha', code: 'A'));
      await local.insert(baseSupplier(id: 'other', name: 'Beta', code: 'B'));
      final res = await repo.update(
        baseSupplier(id: 's1', name: 'Beta', code: 'A'),
      );
      expect(res.isFailure, isTrue);
      res.fold((_) => fail('expected conflict'), (f) {
        expect(f, isA<ValidationFailure>());
        expect(f.message.toLowerCase(), contains('name'));
      });
    });

    test('update clears fields by trimming to null (not keep old)', () async {
      final existing = baseSupplier(
        id: 's1',
        name: 'X',
        code: 'X1',
      ).copyWith(notes: 'Old note', website: 'https://old', city: 'OldCity');
      await local.insert(existing);

      final update = baseSupplier(
        id: 's1',
        name: 'X',
        code: 'X1',
      ).copyWith(notes: '   ', website: '   ', city: '');
      final res = await repo.update(update);
      expect(res.isSuccess, isTrue);
      res.fold((u) {
        expect(u.notes, isNull);
        expect(u.website, isNull);
        expect(u.city, isNull);
      }, (f) => fail('$f'));
    });
  });

  group('SupplierRepositoryImpl - setActive / delete / restore', () {
    test('setActive enqueues UPDATE sync task and bumps version', () async {
      await local.insert(baseSupplier(id: 's1', name: 'S', code: 'S01'));
      final res = await repo.setActive('s1', true);
      expect(res.isSuccess, isTrue);
      expect(queue.tasks.length, 1);
      expect(queue.tasks.first.operation, 'UPDATE');
      res.fold((supplier) {
        expect(supplier.version, 2);
        expect(supplier.syncStatus, SyncStatus.updated);
      }, (_) => fail('Unexpected'));
    });

    test('setActive on missing id returns DatabaseFailure', () async {
      final res = await repo.setActive('no-such', false);
      expect(res.isFailure, isTrue);
      res.fold(
        (_) => fail('Expected failure'),
        (f) => expect(f, isA<DatabaseFailure>()),
      );
      expect(queue.tasks.length, 0);
    });

    test('delete soft-deletes when supplier is NOT in use', () async {
      await local.insert(baseSupplier(id: 's1', name: 'S', code: 'S01'));
      final res = await repo.delete('s1');
      expect(res.isSuccess, true);
      final Supplier? after = await local.findById('s1');
      expect(after?.isDeleted, true);
      expect(after?.deletedAt, isNotNull);
      expect(queue.tasks.length, 1);
      expect(queue.tasks.first.operation, 'DELETE');
    });

    test(
      'delete rejects with ValidationFailure when supplier is in use',
      () async {
        await local.insert(
          baseSupplier(
            id: 'used',
            name: 'U',
            code: 'U01',
            notes: 'INUSE marker',
          ).copyWith(notes: 'INUSE'),
        );
        final res = await repo.delete('used');
        expect(res.isFailure, isTrue);
        res.fold((_) => fail('Expected blocked'), (f) {
          expect(f, isA<ValidationFailure>());
          expect(
            f.message.toLowerCase(),
            contains('purchase') || f.message.toLowerCase().contains('in use'),
          );
        });
        expect(queue.tasks.length, 0);
      },
    );

    test('restore calls restore + enqueues UPDATE and bumps version', () async {
      final Supplier existing = baseSupplier(
        id: 's1',
        name: 'S',
        code: 'S01',
      ).copyWith(isDeleted: true, deletedAt: DateTime.now());
      await local.insert(existing);
      final res = await repo.restore('s1');
      expect(res.isSuccess, true);
      final Supplier? after = await local.findById('s1');
      expect(after?.isDeleted, false);
      expect(after?.deletedAt, isNull);
      expect(queue.tasks.length, 1);
      expect(queue.tasks.first.operation, 'UPDATE');
    });

    test('restore returns DatabaseFailure when id missing', () async {
      final res = await repo.restore('nope');
      expect(res.isFailure, isTrue);
      res.fold(
        (_) => fail('Expected failure'),
        (f) => expect(f, isA<DatabaseFailure>()),
      );
      expect(queue.tasks.length, 0);
    });
  });

  group('SupplierRepositoryImpl - Read queries delegate correctly', () {
    setUp(() async {
      await local.insert(baseSupplier(id: 'a', name: 'Acme One', code: 'A001'));
      await local.insert(baseSupplier(id: 'b', name: 'Acme Two', code: 'A002'));
      await local.insert(
        baseSupplier(id: 'z', name: 'Zero Corp', code: 'ZZZZ', active: false),
      );
    });

    test(
      'findAll passes params: search by name, only active, sorted',
      () async {
        final res = await repo.findAll(
          searchQuery: 'Acme',
          isActive: true,
          sortBy: 'name',
          ascending: true,
          limit: 20,
          offset: 0,
        );
        expect(res.isSuccess, isTrue);
        res.fold((list) {
          expect(list.length, 2);
          expect(list[0].name, startsWith('Acme'));
        }, (_) => fail('Unexpected failure'));
      },
    );

    test('findAll respects includeDeleted', () async {
      await repo.delete('a');
      final withDeleted = await repo.findAll(includeDeleted: true);
      final withoutDeleted = await repo.findAll(includeDeleted: false);
      withDeleted.fold(
        (list) => expect(list.any((s) => s.id == 'a'), true),
        (_) => fail('Err'),
      );
      withoutDeleted.fold(
        (list) => expect(list.any((s) => s.id == 'a'), false),
        (_) => fail('Err'),
      );
    });

    test('findById returns success(null) when missing', () async {
      final res = await repo.findById('nope');
      expect(res.isSuccess, true);
      res.fold((s) => expect(s, isNull), (_) => fail('Unexpected'));
    });

    test('findById returns persisted Supplier', () async {
      final res = await repo.findById('a');
      res.fold((s) => expect(s?.name, 'Acme One'), (_) => fail('Unexpected'));
    });

    test('count delegates with filters', () async {
      final res = await repo.count(searchQuery: 'Acme', isActive: true);
      res.fold((n) => expect(n, 2), (_) => fail('Unexpected'));
    });

    test('count is false only active=false returns 1', () async {
      final res = await repo.count(isActive: false);
      res.fold((n) => expect(n, 1), (_) => fail('Unexpected'));
    });
  });

  group('SupplierRepositoryImpl - aggregate detail queries', () {
    test(
      'countProductsForSupplier returns stored notes:PRODUCTS:N value',
      () async {
        await local.insert(
          baseSupplier(
            id: 'p',
            name: 'P',
            code: 'P01',
          ).copyWith(notes: 'PRODUCTS:7'),
        );
        final res = await repo.countProductsForSupplier('p');
        res.fold((n) => expect(n, 7), (_) => fail('Expected 7'));
      },
    );

    test('countProductsForSupplier returns 0 when missing', () async {
      final res = await repo.countProductsForSupplier('missing');
      res.fold((n) => expect(n, 0), (_) => fail('Expected 0'));
    });

    test(
      'getPurchaseTotals returns creditLimit/currentBalance as total/paid',
      () async {
        await local.insert(
          baseSupplier(
            id: 'q',
            name: 'Q',
            code: 'Q01',
          ).copyWith(creditLimit: 5000, currentBalance: 2000),
        );
        final res = await repo.getPurchaseTotals('q');
        res.fold((m) {
          expect(m['total'], 5000);
          expect(m['paid'], 2000);
        }, (_) => fail('Unexpected'));
      },
    );

    test('getRecentPurchases returns synthetic list of 2 entries', () async {
      await local.insert(baseSupplier(id: 'r', name: 'R', code: 'R01'));
      final res = await repo.getRecentPurchases('r', limit: 5);
      res.fold((list) {
        expect(list.length, 2);
        expect(list[0]['id'], startsWith('PO-r-'));
      }, (_) => fail('Unexpected'));
    });
  });
}
