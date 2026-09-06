import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/app_permission.dart';
import '../../../core/auth/permission_provider.dart';

/// A widget that conditionally shows its [child] based on whether 
/// the current user has the required [permission].
/// 
/// If the user lacks the permission, it can either show a [fallback] widget 
/// or return an empty [SizedBox].
class PermissionGuard extends ConsumerWidget {
  final AppPermission permission;
  final Widget child;
  final Widget? fallback;

  const PermissionGuard({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPermission = ref.watch(hasPermissionProvider(permission));

    if (hasPermission) {
      return child;
    }

    return fallback ?? const SizedBox.shrink();
  }
}
