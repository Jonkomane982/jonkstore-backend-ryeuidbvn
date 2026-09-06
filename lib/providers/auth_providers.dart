import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/auth_repository.dart';
import '../repositories/auth_repository_impl.dart';
import 'repository_providers.dart';
import '../core/domain/models/user.dart';

/// Provider for the AuthRepository.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepositoryImpl(
    userRepository: ref.watch(userRepositoryProvider),
  );
});

/// StreamProvider to listen to auth state changes.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// Provider for the current user.
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).value;
});
