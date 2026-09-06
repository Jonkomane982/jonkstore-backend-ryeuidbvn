import 'package:flutter_test/flutter_test.dart';
import 'package:jonkstore/core/validators/app_validators.dart';
import 'package:jonkstore/core/domain/models/category.dart';

void main() {
  group('Category Validation Tests', () {
    test('Name: should return error message if empty', () {
      final result = AppValidators.required('', 'Name');
      expect(result, 'Name is required');
    });

    test('Name: should return error message if only whitespace', () {
      final result = AppValidators.required('   ', 'Name');
      expect(result, 'Name is required');
    });

    test('Name: should pass with valid name', () {
      final result = AppValidators.required('Electronics', 'Name');
      expect(result, isNull);
    });

    test('Business Rule: Category model should correctly map to 3NF schema JSON', () {
      final now = DateTime.now();
      final category = Category(
        id: 'cat_123',
        name: 'Hardware',
        description: 'Tools and equipment',
        businessId: 'biz_456',
        createdAt: now,
        updatedAt: now,
      );

      final json = category.toJson();

      expect(json['id'], 'cat_123');
      expect(json['name'], 'Hardware');
      expect(json['business_id'], 'biz_456');
      expect(json['is_deleted'], 0);
      expect(json['sync_status'], 'PENDING');
    });
  });
}
