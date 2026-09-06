import 'package:flutter_test/flutter_test.dart';
import 'package:jonkstore/core/validators/app_validators.dart';
import 'package:jonkstore/core/domain/models/supplier.dart';
import 'package:jonkstore/repositories/supplier_repository_impl.dart';
import 'package:jonkstore/core/errors/failures.dart';

void main() {
  group('AppValidators - Supplier Input Validation', () {
    test('required: returns error if empty', () {
      expect(AppValidators.required('', 'Supplier Name'), 'Supplier Name is required');
    });
    test('required: returns error if only whitespace', () {
      expect(AppValidators.required('   \t', 'Supplier Name'), 'Supplier Name is required');
    });
    test('required: returns null when valid', () {
      expect(AppValidators.required('Acme Supplies', 'Supplier Name'), isNull);
    });

    test('email: null when empty (optional)', () {
      expect(SupplierRepositoryImpl.validateEmailFormat(''), isNull);
      expect(SupplierRepositoryImpl.validateEmailFormat(null), isNull);
      expect(SupplierRepositoryImpl.validateEmailFormat('   '), isNull);
    });
    test('email: fails invalid', () {
      final r = SupplierRepositoryImpl.validateEmailFormat('not-an-email');
      expect(r, isA<ValidationFailure>());
      expect(r!.message, contains('valid email'));
    });
    test('email: passes valid formats', () {
      expect(SupplierRepositoryImpl.validateEmailFormat('supplier@example.com'), isNull);
      expect(SupplierRepositoryImpl.validateEmailFormat(' first.last+tag@domain.co.uk '), isNull);
    });

    test('phone: null when empty (optional)', () {
      expect(SupplierRepositoryImpl.validatePhoneFormat(''), isNull);
      expect(SupplierRepositoryImpl.validatePhoneFormat(null), isNull);
      expect(SupplierRepositoryImpl.validatePhoneFormat('  '), isNull);
    });
    test('phone: fails too short', () {
      final r = SupplierRepositoryImpl.validatePhoneFormat('12');
      expect(r, isA<ValidationFailure>());
      expect(r!.message, contains('valid phone'));
    });
    test('phone: accepts international + spaces + parens', () {
      expect(SupplierRepositoryImpl.validatePhoneFormat('+254 700 000 000'), isNull);
      expect(SupplierRepositoryImpl.validatePhoneFormat('(555) 123-4567'), isNull);
      expect(SupplierRepositoryImpl.validatePhoneFormat('0712345678'), isNull);
    });

    test('trimOrNull normalizes inputs', () {
      expect(SupplierRepositoryImpl.trimOrNull(null), isNull);
      expect(SupplierRepositoryImpl.trimOrNull('   '), isNull);
      expect(SupplierRepositoryImpl.trimOrNull(' Acme '), 'Acme');
    });
  });

  group('Supplier Model - Schema Ser/De Round-Trip', () {
    test('toJson/fromJson preserves full schema fields', () {
      final now = DateTime.now().toUtc();
      final supplier = Supplier(
        id: 'sup_001',
        businessId: 'biz_001',
        name: 'Acme Wholesalers',
        code: 'SUP-001',
        taxId: 'PIN-A12345678Z',
        website: 'https://acme.example.com',
        email: 'ap@acme.example.com',
        phone: '+254 700 000 000',
        address: '123 Industrial Rd',
        city: 'Nairobi',
        state: 'Nairobi Area',
        country: 'Kenya',
        postalCode: '00100',
        contactName: 'Jane Smith',
        paymentTerms: 'Net 30',
        creditLimit: 500000.0,
        currentBalance: 12500.50,
        notes: 'Deliver every Tuesday',
        isActive: true,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
        isDeleted: false,
        version: 2,
        createdBy: 'user_1',
        updatedBy: 'user_2',
      );

      final json = supplier.toJson();
      expect(json['id'], 'sup_001');
      expect(json['business_id'], 'biz_001');
      expect(json['code'], 'SUP-001');
      expect(json['tax_id'], 'PIN-A12345678Z');
      expect(json['website'], 'https://acme.example.com');
      expect(json['city'], 'Nairobi');
      expect(json['state'], 'Nairobi Area');
      expect(json['country'], 'Kenya');
      expect(json['postal_code'], '00100');
      expect(json['payment_terms'], 'Net 30');
      expect(json['credit_limit'], 500000.0);
      expect(json['current_balance'], 12500.50);
      expect(json['notes'], 'Deliver every Tuesday');
      expect(json['version'], 2);
      expect(json['is_deleted'], 0);
      expect(json['is_active'], 1);

      final restored = Supplier.fromJson(json);
      expect(restored.id, supplier.id);
      expect(restored.name, supplier.name);
      expect(restored.taxId, supplier.taxId);
      expect(restored.website, supplier.website);
      expect(restored.city, supplier.city);
      expect(restored.state, supplier.state);
      expect(restored.country, supplier.country);
      expect(restored.postalCode, supplier.postalCode);
      expect(restored.paymentTerms, supplier.paymentTerms);
      expect(restored.creditLimit, supplier.creditLimit);
      expect(restored.currentBalance, supplier.currentBalance);
      expect(restored.notes, supplier.notes);
      expect(restored.createdBy, supplier.createdBy);
      expect(restored.updatedBy, supplier.updatedBy);
      expect(restored.version, 2);
    });

    test('fromJson gracefully handles new fields being null (backward compat)', () {
      final json = <String, dynamic>{
        'id': 'sup_old',
        'name': 'Old Supplier',
        'code': '',
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      final s = Supplier.fromJson(json);
      expect(s.id, 'sup_old');
      expect(s.name, 'Old Supplier');
      expect(s.creditLimit, 0.0);
      expect(s.currentBalance, 0.0);
      expect(s.city, isNull);
      expect(s.country, isNull);
      expect(s.taxId, isNull);
      expect(s.isActive, true);
    });

    test('copyWith preserves omitted fields and updates specified ones', () {
      final now = DateTime.now();
      final base = Supplier(
        id: 'c1',
        name: 'Base',
        code: 'B01',
        createdAt: now,
        updatedAt: now,
      );
      final updated = base.copyWith(name: 'Updated', isActive: false);
      expect(updated.id, 'c1');
      expect(updated.code, 'B01');
      expect(updated.name, 'Updated');
      expect(updated.isActive, false);
      expect(updated.createdAt, now);
    });
  });
}
