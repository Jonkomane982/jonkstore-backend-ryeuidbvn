import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/enums/user_role.dart';
import 'app_permission.dart';
import 'authorization_service.dart';

/// Provider for the [AuthorizationService].
final authorizationServiceProvider = Provider<AuthorizationService>((ref) {
  return AuthorizationService();
});

/// Mock provider for the current user's role.
/// 
/// In a real scenario, this would be updated upon login.
/// For now, it defaults to [UserRole.owner] to allow development.
final currentUserRoleProvider = StateProvider<UserRole>((ref) {
  return UserRole.owner;
});

/// Provider to check if the current user has a specific permission.
final hasPermissionProvider = Provider.family<bool, AppPermission>((ref, permission) {
  final role = ref.watch(currentUserRoleProvider);
  final authService = ref.watch(authorizationServiceProvider);
  return authService.hasPermission(role, permission);
});
