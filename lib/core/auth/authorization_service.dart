import '../domain/enums/user_role.dart';
import 'app_permission.dart';
import 'role_permissions.dart';

/// Service responsible for authorizing actions based on user roles and permissions.
class AuthorizationService {
  /// Checks if a given [role] has the specified [permission].
  bool hasPermission(UserRole role, AppPermission permission) {
    final permissions = RolePermissions.getPermissionsForRole(role);
    return permissions.contains(permission);
  }

  /// Checks if a given [role] has all of the specified [permissions].
  bool hasAllPermissions(UserRole role, List<AppPermission> permissions) {
    final userPermissions = RolePermissions.getPermissionsForRole(role);
    return permissions.every((p) => userPermissions.contains(p));
  }

  /// Checks if a given [role] has at least one of the specified [permissions].
  bool hasAnyPermission(UserRole role, List<AppPermission> permissions) {
    final userPermissions = RolePermissions.getPermissionsForRole(role);
    return permissions.any((p) => userPermissions.contains(p));
  }
}
