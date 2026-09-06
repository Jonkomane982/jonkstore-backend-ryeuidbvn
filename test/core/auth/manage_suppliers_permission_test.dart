import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jonkstore/core/auth/app_permission.dart';
import 'package:jonkstore/core/auth/authorization_service.dart';
import 'package:jonkstore/core/auth/permission_provider.dart';
import 'package:jonkstore/core/auth/role_permissions.dart';
import 'package:jonkstore/core/domain/enums/user_role.dart';

void main() {
  group(
    'RolePermissions.getPermissionsForRole - manageSuppliers assignments',
    () {
      test('Owner role has manageSuppliers permission', () {
        final perms = RolePermissions.getPermissionsForRole(UserRole.owner);
        expect(perms, contains(AppPermission.manageSuppliers));
      });

      test('Manager role has manageSuppliers permission', () {
        final perms = RolePermissions.getPermissionsForRole(UserRole.manager);
        expect(perms, contains(AppPermission.manageSuppliers));
      });

      test('Cashier role does NOT have manageSuppliers permission', () {
        final perms = RolePermissions.getPermissionsForRole(UserRole.cashier);
        expect(perms.contains(AppPermission.manageSuppliers), isFalse);
      });

      test('Store Assistant does NOT have manageSuppliers permission', () {
        final perms = RolePermissions.getPermissionsForRole(
          UserRole.storeAssistant,
        );
        expect(perms.contains(AppPermission.manageSuppliers), isFalse);
      });

      test('Admin role has manageSuppliers permission', () {
        final perms = RolePermissions.getPermissionsForRole(UserRole.admin);
        expect(perms, contains(AppPermission.manageSuppliers));
      });
    },
  );

  group('AuthorizationService.hasPermission checks', () {
    final svc = AuthorizationService();

    test('owner user has manageSuppliers', () {
      expect(
        svc.hasPermission(UserRole.owner, AppPermission.manageSuppliers),
        true,
      );
    });

    test('manager user has manageSuppliers', () {
      expect(
        svc.hasPermission(UserRole.manager, AppPermission.manageSuppliers),
        true,
      );
    });

    test('cashier lacks manageSuppliers', () {
      expect(
        svc.hasPermission(UserRole.cashier, AppPermission.manageSuppliers),
        false,
      );
    });

    test('storeAssistant lacks manageSuppliers', () {
      expect(
        svc.hasPermission(
          UserRole.storeAssistant,
          AppPermission.manageSuppliers,
        ),
        false,
      );
    });

    test('admin has manageSuppliers', () {
      expect(
        svc.hasPermission(UserRole.admin, AppPermission.manageSuppliers),
        true,
      );
    });
  });

  group('AuthorizationService.hasAllPermissions / hasAnyPermission', () {
    final svc = AuthorizationService();

    test(
      'owner has ALL permissions (includes manageSuppliers + manageSettings + manageEmployees)',
      () {
        final all = [
          AppPermission.manageSuppliers,
          AppPermission.manageSettings,
          AppPermission.manageEmployees,
        ];
        expect(svc.hasAllPermissions(UserRole.owner, all), true);
      },
    );

    test(
      'manager has manageSuppliers but NOT manageEmployees -> hasAllPermissions fails',
      () {
        final all = [
          AppPermission.manageSuppliers,
          AppPermission.manageEmployees,
        ];
        expect(svc.hasAllPermissions(UserRole.manager, all), false);
      },
    );

    test(
      'manager has ANY of (manageSuppliers, manageEmployees) because has manageSuppliers',
      () {
        final any = [
          AppPermission.manageSuppliers,
          AppPermission.manageEmployees,
        ];
        expect(svc.hasAnyPermission(UserRole.manager, any), true);
      },
    );

    test(
      'cashier has ANY of (manageSales, manageSuppliers) because has manageSales',
      () {
        final any = [AppPermission.manageSales, AppPermission.manageSuppliers];
        expect(svc.hasAnyPermission(UserRole.cashier, any), true);
      },
    );

    test('cashier does not have ANY of (manageSuppliers, managePurchases)', () {
      final any = [
        AppPermission.manageSuppliers,
        AppPermission.managePurchases,
      ];
      expect(svc.hasAnyPermission(UserRole.cashier, any), false);
    });
  });

  group('hasPermissionProvider riverpod family behavior', () {
    test('returns true for default owner role', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final res = container.read(
        hasPermissionProvider(AppPermission.manageSuppliers),
      );
      expect(res, true);
    });

    test('returns true when currentUserRoleProvider is manager', () {
      final container = ProviderContainer(
        overrides: [
          currentUserRoleProvider.overrideWith((ref) => UserRole.manager),
        ],
      );
      addTearDown(container.dispose);
      final ok = container.read(
        hasPermissionProvider(AppPermission.manageSuppliers),
      );
      expect(ok, true);
    });

    test('returns false when currentUserRoleProvider is cashier', () {
      final container = ProviderContainer(
        overrides: [
          currentUserRoleProvider.overrideWith((ref) => UserRole.cashier),
        ],
      );
      addTearDown(container.dispose);
      final ok = container.read(
        hasPermissionProvider(AppPermission.manageSuppliers),
      );
      expect(ok, false);
    });

    test('returns false when currentUserRoleProvider is storeAssistant', () {
      final container = ProviderContainer(
        overrides: [
          currentUserRoleProvider.overrideWith(
            (ref) => UserRole.storeAssistant,
          ),
        ],
      );
      addTearDown(container.dispose);
      final ok = container.read(
        hasPermissionProvider(AppPermission.manageSuppliers),
      );
      expect(ok, false);
    });

    test('returns true when currentUserRoleProvider is admin', () {
      final container = ProviderContainer(
        overrides: [
          currentUserRoleProvider.overrideWith((ref) => UserRole.admin),
        ],
      );
      addTearDown(container.dispose);
      final ok = container.read(
        hasPermissionProvider(AppPermission.manageSuppliers),
      );
      expect(ok, true);
    });

    test('cashier CAN manageSales even though they cannot manageSuppliers', () {
      final container = ProviderContainer(
        overrides: [
          currentUserRoleProvider.overrideWith((ref) => UserRole.cashier),
        ],
      );
      addTearDown(container.dispose);
      expect(
        container.read(hasPermissionProvider(AppPermission.manageSales)),
        true,
      );
      expect(
        container.read(hasPermissionProvider(AppPermission.manageSuppliers)),
        false,
      );
    });
  });
}
