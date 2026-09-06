import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jonkstore/core/domain/models/employee.dart';
import 'package:jonkstore/repositories/employee_repository.dart';
import 'package:jonkstore/providers/repository_providers.dart';

class EmployeeState {
  final bool isLoading;
  final String? errorMessage;
  final List<Employee> employees;

  EmployeeState({
    this.isLoading = false,
    this.errorMessage,
    this.employees = const [],
  });

  EmployeeState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<Employee>? employees,
  }) {
    return EmployeeState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      employees: employees ?? this.employees,
    );
  }
}

class EmployeeController extends StateNotifier<EmployeeState> {
  final EmployeeRepository _repository;

  EmployeeController(this._repository) : super(EmployeeState());

  Future<void> loadEmployees() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final result = await _repository.findAll();
    result.fold(
      (employees) => state = state.copyWith(isLoading: false, employees: employees),
      (failure) => state = state.copyWith(isLoading: false, errorMessage: failure.message),
    );
  }

  Future<void> deleteEmployee(String id) async {
    final result = await _repository.delete(id);
    result.fold((_) => loadEmployees(), (f) => null);
  }
}

final employeeControllerProvider = StateNotifierProvider<EmployeeController, EmployeeState>((ref) {
  return EmployeeController(ref.watch(employeeRepositoryProvider));
});
