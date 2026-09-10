import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jonkstore/core/domain/models/inventory.dart';
import 'package:jonkstore/core/domain/models/product.dart';
import 'package:jonkstore/features/auth/presentation/owner_login_screen.dart';
import 'package:jonkstore/features/auth/presentation/owner_register_screen.dart';
import 'package:jonkstore/features/auth/presentation/owner_verify_email_screen.dart';
import 'package:jonkstore/features/auth/presentation/owner_forgot_password_screen.dart';
import 'route_names.dart';
import '../../features/onboarding/presentation/splash_screen.dart';
import '../../features/onboarding/presentation/business_setup_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/products/presentation/product_list_screen.dart';
import '../../features/products/presentation/product_form_screen.dart';
import '../../features/products/presentation/category_list_screen.dart';
import '../../features/inventory/presentation/inventory_list_screen.dart';
import '../../features/inventory/presentation/inventory_history_screen.dart';
import '../../features/inventory/presentation/inventory_adjustment_screen.dart';
import '../../features/sales/presentation/sales_screen.dart';
import '../../features/customers/presentation/customer_list_screen.dart';
import '../../features/suppliers/presentation/supplier_list_screen.dart';
import '../../features/employees/presentation/employee_list_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/notifications/presentation/notification_list_screen.dart';
import '../../features/ai/presentation/ai_assistant_screen.dart';
import '../../features/ai/presentation/jonkai_chat_screen.dart';
import '../../features/ai/presentation/jonkai_profile_screen.dart';

/// Centralized router configuration for JonkStore POS.
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: true,
  routes: [
    GoRoute(
      path: '/',
      name: RouteNames.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      name: RouteNames.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      name: RouteNames.register,
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      name: RouteNames.forgotPassword,
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/verify-email',
      name: RouteNames.verifyEmail,
      builder: (context, state) => const VerifyEmailScreen(),
    ),
    GoRoute(
      path: '/business-setup',
      name: RouteNames.businessSetup,
      builder: (context, state) => const BusinessSetupScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      name: RouteNames.dashboard,
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/user-management',
      name: RouteNames.userManagement,
      builder: (context, state) => const UserManagementScreen(),
    ),

    // Product Management Routes
    GoRoute(
      path: '/products',
      name: RouteNames.products,
      builder: (context, state) => const ProductListScreen(),
      routes: [
        GoRoute(
          path: 'add',
          name: RouteNames.productAdd,
          builder: (context, state) => const ProductFormScreen(),
        ),
        // ... existing edit route
        GoRoute(
          path: 'edit/:id',
          name: RouteNames.productEdit,
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return ProductFormScreen(productId: id);
          },
        ),
        GoRoute(
          path: 'categories',
          name: RouteNames.categories,
          builder: (context, state) => const CategoryListScreen(),
        ),
      ],
    ),

    // Inventory Management Routes
    GoRoute(
      path: '/inventory',
      name: RouteNames.inventory,
      builder: (context, state) => const InventoryListScreen(),
      routes: [
        GoRoute(
          path: 'history/:id',
          name: RouteNames.inventoryHistory,
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return InventoryHistoryScreen(productId: id);
          },
        ),
        GoRoute(
          path: 'adjustment',
          name: RouteNames.inventoryAdjustment,
          builder: (context, state) {
            final extras = state.extra as Map<String, dynamic>;
            return InventoryAdjustmentScreen(
              product: extras['product'] as Product,
              inventory: extras['inventory'] as Inventory,
            );
          },
        ),
      ],
    ),

    GoRoute(
      path: '/sales',
      name: RouteNames.sales,
      builder: (context, state) => const SalesScreen(),
    ),

    // ... Other existing management routes (Customers, Suppliers, Employees, etc.)
    GoRoute(
      path: '/customers',
      name: RouteNames.customers,
      builder: (context, state) => const CustomerListScreen(),
    ),
    GoRoute(
      path: '/suppliers',
      name: RouteNames.suppliers,
      builder: (context, state) => const SupplierListScreen(),
    ),
    GoRoute(
      path: '/employees',
      name: RouteNames.employees,
      builder: (context, state) => const EmployeeListScreen(),
    ),

    GoRoute(
      path: '/reports',
      name: RouteNames.reports,
      builder: (context, state) => const ReportsScreen(),
    ),
    GoRoute(
      path: '/notifications',
      name: RouteNames.notifications,
      builder: (context, state) => const NotificationListScreen(),
    ),

    // --- JonkAI AI Suite ---
    GoRoute(
      path: '/ai-insights',
      name: RouteNames.aiAssistant,
      builder: (context, state) => const AIAssistantScreen(),
    ),
    GoRoute(
      path: '/jonkai',
      name: RouteNames.aiChat,
      builder: (context, state) => const JonkAIChatScreen(),
    ),
    GoRoute(
      path: '/ai-profile',
      name: RouteNames.aiProfile,
      builder: (context, state) => const JonkAIProfileScreen(),
    ),

    GoRoute(
      path: '/settings',
      name: RouteNames.settings,
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
