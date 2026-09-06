import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/domain/models/business.dart';
import '../../../core/domain/enums/sync_status.dart';
import '../../../core/services/owner_service.dart';
import '../../../database/database_service.dart';
import '../../../providers/owner_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../../core/providers/core_providers.dart';

/// State for the Business Setup process.
class BusinessSetupState {
  final bool isLoading;
  final String? errorMessage;
  final bool isSuccess;
  final String? createdBusinessId;

  BusinessSetupState({
    this.isLoading = false,
    this.errorMessage,
    this.isSuccess = false,
    this.createdBusinessId,
  });

  BusinessSetupState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? isSuccess,
    String? createdBusinessId,
  }) {
    return BusinessSetupState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isSuccess: isSuccess ?? this.isSuccess,
      createdBusinessId: createdBusinessId ?? this.createdBusinessId,
    );
  }
}

/// Controller for handling business setup logic.
///
/// The controller is responsible for:
///  1. Building the Business row (with required currency_id FK).
///  2. Writing Business + OwnerProfile atomically in a single SQLite
///     transaction so an owner_profile with NULL business_id can never exist.
///  3. Delegating OwnerProfile construction to OwnerService (the only
///     authorized writer for that table).
class BusinessSetupController extends StateNotifier<BusinessSetupState> {
  final Ref _ref;

  BusinessSetupController(this._ref) : super(BusinessSetupState());

  /// Maps a free-text currency code (e.g. "KES", "USD") to its seeded
  /// currency id. Falls back to CUR001 (KES) if no match is found.
  static String resolveCurrencyId(String currencyCode) {
    final upper = currencyCode.trim().toUpperCase();
    switch (upper) {
      case 'KES':
      case 'KSH':
        return 'CUR001';
      case 'USD':
      case r'$':
        return 'CUR002';
      case 'UGX':
        return 'CUR003';
      default:
        return 'CUR001';
    }
  }

  Future<void> createBusiness({
    required String name,
    required String email,
    required String phone,
    required String address,
    required String country,
    required String currency,
    required String businessType,
    required String timezone,
    required String receiptFooter,
    String? logoUrl,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final DatabaseService dbService = _ref.read(databaseServiceProvider);
    final businessRepo = _ref.read(businessRepositoryProvider);
    final OwnerService ownerService = _ref.read(ownerServiceProvider);

    final currencyId = resolveCurrencyId(currency);
    final business = Business(
      id: const Uuid().v4(),
      name: name.trim(),
      email: email.trim().isEmpty ? null : email.trim(),
      phone: phone.trim().isEmpty ? null : phone.trim(),
      address: address.trim().isEmpty ? null : address.trim(),
      country: country.trim().isEmpty ? null : country.trim(),
      currency: currency.trim().isEmpty ? null : currency.trim(),
      businessType: businessType.trim().isEmpty ? null : businessType.trim(),
      receiptFooter: receiptFooter.trim().isEmpty ? null : receiptFooter.trim(),
      logoUrl: logoUrl,
      currencyId: currencyId,
      baseTimezone: timezone.trim().isEmpty ? 'UTC' : timezone.trim(),
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );

    try {
      await dbService.transaction<void>((Transaction txn) async {
        final createResult = await businessRepo.create(business, txn: txn);
        if (createResult.isFailure) {
          throw Exception(createResult.failure.message);
        }

        final profileResult = await ownerService.completeOnboardingWithBusiness(
          businessId: business.id,
          txn: txn,
        );
        if (profileResult.isFailure) {
          throw Exception(profileResult.failure.message);
        }
      });

      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        createdBusinessId: business.id,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}

/// Provider for the BusinessSetupController.
final businessSetupControllerProvider =
    StateNotifierProvider<BusinessSetupController, BusinessSetupState>((ref) {
      return BusinessSetupController(ref);
    });

/// Provider to check if a business is already configured.
final isBusinessConfiguredProvider = FutureProvider<bool>((ref) async {
  final repository = ref.watch(businessRepositoryProvider);
  final countResult = await repository.count();

  return countResult.fold((count) => count > 0, (failure) => false);
});
