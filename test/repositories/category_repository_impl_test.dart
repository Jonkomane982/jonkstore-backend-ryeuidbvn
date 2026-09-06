import 'package:flutter_test/flutter_test.dart';
import 'package:jonkstore/core/domain/models/category.dart';
import 'package:jonkstore/core/errors/failures.dart';
import 'package:jonkstore/datasources/local/category_local_datasource.dart';
import 'package:jonkstore/repositories/category_repository_impl.dart';
import 'package:jonkstore/sync/queue/sync_queue.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uuid/uuid.dart';

class MockCategoryLocalDataSource extends Mock implements CategoryLocalDataSource {}
class MockSyncQueue extends Mock implements SyncQueue {}
class FakeCategory extends Fake implements Category {}

void main() {
  late CategoryRepositoryImpl repository;
  late MockCategoryLocalDataSource mockDataSource;
  late MockSyncQueue mockSyncQueue;

  setUpAll(() {
    registerFallbackValue(FakeCategory());
  });

  setUp(() {
    mockDataSource = MockCategoryLocalDataSource();
    mockSyncQueue = MockSyncQueue();
    repository = CategoryRepositoryImpl(
      localDataSource: mockDataSource,
      syncQueue: mockSyncQueue,
    );
  });

  group('CategoryRepository Production Logic Tests', () {
    final tId = const Uuid().v4();
    final tCategory = Category(
      id: tId,
      name: 'Test Category',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    test('create should return ValidationFailure if name already exists', () async {
      // Arrange
      when(() => mockDataSource.findByName('Test Category')).thenAnswer((_) async => tCategory);

      // Act
      final result = await repository.create(tCategory);

      // Assert
      expect(result.isFailure, true);
      expect(result.failure, isA<ValidationFailure>());
      expect(result.failure.message, contains('already exists'));
      verify(() => mockDataSource.findByName('Test Category')).called(1);
      verifyNever(() => mockDataSource.insert(any()));
    });

    test('create should persist locally and queue sync if valid', () async {
      // Arrange
      when(() => mockDataSource.findByName(any())).thenAnswer((_) async => null);
      when(() => mockDataSource.insert(any())).thenAnswer((_) async => {});
      when(() => mockSyncQueue.addTask(any())).thenAnswer((_) async => {});
      // For stream notification
      when(() => mockDataSource.findAll(
            searchQuery: any(named: 'searchQuery'),
            sortBy: any(named: 'sortBy'),
            ascending: any(named: 'ascending'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            includeDeleted: any(named: 'includeDeleted'),
          )).thenAnswer((_) async => [tCategory]);

      // Act
      final result = await repository.create(tCategory);

      // Assert
      expect(result.isSuccess, true);
      verify(() => mockDataSource.insert(any())).called(1);
      verify(() => mockSyncQueue.addTask(any())).called(1);
    });

    test('delete should fail if category is in use by products', () async {
      // Arrange
      when(() => mockDataSource.isCategoryInUse(tId)).thenAnswer((_) async => true);

      // Act
      final result = await repository.delete(tId);

      // Assert
      expect(result.isFailure, true);
      expect(result.failure, isA<ValidationFailure>());
      expect(result.failure.message, contains('assigned to one or more products'));
      verifyNever(() => mockDataSource.softDelete(any(), any()));
    });

    test('delete should perform soft delete and queue sync if not in use', () async {
      // Arrange
      when(() => mockDataSource.isCategoryInUse(tId)).thenAnswer((_) async => false);
      when(() => mockDataSource.findById(tId)).thenAnswer((_) async => tCategory);
      when(() => mockDataSource.softDelete(any(), any())).thenAnswer((_) async => {});
      when(() => mockSyncQueue.addTask(any())).thenAnswer((_) async => {});
      when(() => mockDataSource.findAll(
            searchQuery: any(named: 'searchQuery'),
            sortBy: any(named: 'sortBy'),
            ascending: any(named: 'ascending'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            includeDeleted: any(named: 'includeDeleted'),
          )).thenAnswer((_) async => []);

      // Act
      final result = await repository.delete(tId);

      // Assert
      expect(result.isSuccess, true);
      verify(() => mockDataSource.softDelete(tId, any())).called(1);
      verify(() => mockSyncQueue.addTask(any())).called(1);
    });
  });
}
