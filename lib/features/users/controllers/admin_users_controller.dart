import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/domain/enums/user_role.dart';
import '../../../core/errors/failures.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/result.dart';

enum AccountStatus { pending, active, suspended }

class AdminUser {
  final String id;
  final String email;
  final String username;
  final UserRole role;
  final AccountStatus accountStatus;
  final bool isActive;
  final DateTime? lastLoginAt;
  final DateTime? createdAt;

  AdminUser({
    required this.id,
    required this.email,
    required this.username,
    required this.role,
    required this.accountStatus,
    required this.isActive,
    this.lastLoginAt,
    this.createdAt,
  });

  static UserRole _parseRole(dynamic role) {
    final r = (role ?? 'cashier').toString().toLowerCase().replaceAll('_', '');
    switch (r) {
      case 'admin':
        return UserRole.admin;
      case 'owner':
        return UserRole.owner;
      case 'manager':
        return UserRole.manager;
      case 'cashier':
        return UserRole.cashier;
      case 'storeassistant':
      case 'store_assistant':
        return UserRole.storeAssistant;
      default:
        return UserRole.cashier;
    }
  }

  static AccountStatus _parseStatus(dynamic status) {
    final s = (status ?? 'active').toString().toLowerCase();
    switch (s) {
      case 'pending':
        return AccountStatus.pending;
      case 'suspended':
        return AccountStatus.suspended;
      case 'active':
      default:
        return AccountStatus.active;
    }
  }

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      username: (json['username'] ?? json['name'] ?? '').toString(),
      role: _parseRole(json['role'] ?? json['role_name']),
      accountStatus: _parseStatus(json['accountStatus'] ?? json['account_status']),
      isActive: json['isActive'] ?? json['is_active'] ?? true,
      lastLoginAt: json['lastLoginAt'] != null || json['last_login_at'] != null
          ? DateTime.tryParse((json['lastLoginAt'] ?? json['last_login_at']).toString())
          : null,
      createdAt: json['createdAt'] != null || json['created_at'] != null
          ? DateTime.tryParse((json['createdAt'] ?? json['created_at']).toString())
          : null,
    );
  }
}

class AdminUsersState {
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;
  final List<AdminUser> users;
  final int currentPage;
  final int totalPages;
  final int total;
  final String? searchQuery;
  final UserRole? filterRole;
  final AccountStatus? filterStatus;

  AdminUsersState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
    this.users = const [],
    this.currentPage = 1,
    this.totalPages = 1,
    this.total = 0,
    this.searchQuery,
    this.filterRole,
    this.filterStatus,
  });

  AdminUsersState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    List<AdminUser>? users,
    int? currentPage,
    int? totalPages,
    int? total,
    String? searchQuery,
    UserRole? filterRole,
    AccountStatus? filterStatus,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return AdminUsersState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      users: users ?? this.users,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      total: total ?? this.total,
      searchQuery: searchQuery ?? this.searchQuery,
      filterRole: filterRole ?? this.filterRole,
      filterStatus: filterStatus ?? this.filterStatus,
    );
  }
}

class AdminUsersController extends StateNotifier<AdminUsersState> {
  final Ref _ref;
  final ApiClient _api;

  AdminUsersController(this._ref, ApiClient? api)
      : _api = api ?? ApiClient(),
        super(AdminUsersState());

  Future<void> loadUsers() async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    final params = <String, dynamic>{
      'page': state.currentPage,
      'limit': 50,
    };
    if (state.searchQuery != null && state.searchQuery!.isNotEmpty) {
      params['search'] = state.searchQuery;
    }
    if (state.filterRole != null) {
      params['role'] = state.filterRole!.name.toUpperCase().replaceAll('storeAssistant', 'STORE_ASSISTANT');
    }
    if (state.filterStatus != null) {
      params['status'] = state.filterStatus!.name;
    }
    try {
      final res = await _api.get('/auth/users', queryParameters: params);
      final data = (res.data is Map) ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
      final items = (data['data']?['items'] as List?) ?? <dynamic>[];
      final pagination = data['data']?['pagination'] as Map? ?? <String, dynamic>{};
      final users = items
          .map((e) => AdminUser.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false);
      state = state.copyWith(
        isLoading: false,
        users: users,
        total: (pagination['total'] as int?) ?? 0,
        totalPages: (pagination['totalPages'] as int?) ?? 1,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  void setFilters({String? search, UserRole? role, AccountStatus? status, bool clearRole = false, bool clearStatus = false}) {
    state = state.copyWith(
      searchQuery: search,
      filterRole: clearRole ? null : role ?? state.filterRole,
      filterStatus: clearStatus ? null : status ?? state.filterStatus,
      currentPage: 1,
    );
    loadUsers();
  }

  void goToPage(int page) {
    if (page < 1 || page > state.totalPages) return;
    state = state.copyWith(currentPage: page);
    loadUsers();
  }

  Future<Result<void>> _mutate(Future<dynamic> Function() call, {String? onSuccess}) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      await call();
      state = state.copyWith(
        isLoading: false,
        successMessage: onSuccess ?? 'Operation completed successfully',
      );
      await loadUsers();
      return Result.success(null);
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return Result.failure(Failure(message: msg));
    }
  }

  Future<Result<void>> updateStatus(String userId, AccountStatus status) {
    return _mutate(
      () => _api.patch('/auth/users/$userId/status', data: {'status': status.name}),
      onSuccess: 'User status updated to ${status.name}',
    );
  }

  Future<Result<void>> updateRole(String userId, UserRole role) {
    final roleName = role == UserRole.storeAssistant ? 'STORE_ASSISTANT' : role.name.toUpperCase();
    return _mutate(
      () => _api.patch('/auth/users/$userId/role', data: {'role': roleName}),
      onSuccess: 'User role updated to ${role.name}',
    );
  }

  Future<Result<void>> deleteUser(String userId) {
    return _mutate(
      () => _api.delete('/auth/users/$userId'),
      onSuccess: 'User deleted successfully',
    );
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }
}

final adminUsersControllerProvider =
    StateNotifierProvider<AdminUsersController, AdminUsersState>((ref) {
  return AdminUsersController(ref, null);
});
