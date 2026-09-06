import '../domain/enums/user_role.dart';
import 'app_permission.dart';

/// Mapping of [UserRole] to their respective [AppPermission] sets.
class RolePermissions {
  static final Map<UserRole, Set<AppPermission>> _roleMapping = {
    UserRole.owner: AppPermission.values.toSet(),

    UserRole.admin: AppPermission.values.toSet(),

    UserRole.manager: {
      AppPermission.viewDashboard,
      AppPermission.manageProducts,
      AppPermission.manageCategories,
      AppPermission.manageInventory,
      AppPermission.manageCustomers,
      AppPermission.manageSuppliers,
      AppPermission.managePurchases,
      AppPermission.manageReports,
      AppPermission.manageNotifications,
      AppPermission.useAi,
    },

    UserRole.cashier: {
      AppPermission.viewDashboard,
      AppPermission.manageSales,
      AppPermission.manageCustomers,
      AppPermission.manageNotifications,
    },

    UserRole.storeAssistant: {
      AppPermission.viewDashboard,
      AppPermission.manageInventory,
      AppPermission.manageNotifications,
    },
  };

  /// Returns the set of permissions assigned to a given role.
  static Set<AppPermission> getPermissionsForRole(UserRole role) {
    return _roleMapping[role] ?? {};
  }
}
