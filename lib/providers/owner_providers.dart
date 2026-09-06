import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jonkstore/core/providers/core_providers.dart';
import 'package:jonkstore/core/services/owner_service.dart';
import 'package:jonkstore/core/services/otp_service.dart';
import 'package:jonkstore/core/domain/models/owner_profile.dart';
import 'package:jonkstore/datasources/local/owner_local_datasource.dart';
import 'package:jonkstore/repositories/owner_repository.dart';
import 'package:jonkstore/repositories/owner_repository_impl.dart';

/// Provider for the [OwnerLocalDataSource].
final ownerLocalDataSourceProvider = Provider<OwnerLocalDataSource>((ref) {
  return OwnerLocalDataSource(ref.watch(databaseServiceProvider));
});

/// Provider for the [OwnerRepository].
final ownerRepositoryProvider = Provider<OwnerRepository>((ref) {
  return OwnerRepositoryImpl(ref.watch(ownerLocalDataSourceProvider));
});

/// Provider for the [OtpService] used by [OwnerService] for OTP lifecycle.
final otpServiceForOwnerProvider = Provider<OtpService>((ref) {
  return OtpService();
});

/// Provider for the [OwnerService].
final ownerServiceProvider = Provider<OwnerService>((ref) {
  return OwnerService(
    FirebaseAuth.instance,
    ref.watch(ownerRepositoryProvider),
    ref.watch(otpServiceForOwnerProvider),
    ref.watch(apiClientProvider),
  );
});

/// FutureProvider to fetch the current owner's profile.
final currentOwnerProfileProvider = FutureProvider<OwnerProfile?>((ref) async {
  final repository = ref.watch(ownerRepositoryProvider);
  final result = await repository.getProfile();
  return result.fold(
    (profile) => profile,
    (failure) => null,
  );
});
