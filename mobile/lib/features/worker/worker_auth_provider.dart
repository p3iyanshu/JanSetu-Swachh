import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/worker_session_service.dart';
import '../../data/models/department_model.dart';
import '../../data/models/officer_model.dart';
import '../../data/repositories/worker_repository.dart';
import '../report/report_provider.dart' show apiClientProvider;

final workerRepositoryProvider = Provider((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return WorkerRepository(apiClient);
});

final workerSessionServiceProvider = Provider((ref) => WorkerSessionService());

class WorkerAuthState {
  final OfficerModel? officer;
  final List<DepartmentModel> departments;
  final bool isLoading;
  final bool isRestoring;
  final bool isLoadingDepartments;
  final String? error;

  const WorkerAuthState({
    this.officer,
    this.departments = const [],
    this.isLoading = false,
    this.isRestoring = true,
    this.isLoadingDepartments = false,
    this.error,
  });

  bool get isLoggedIn => officer != null;

  WorkerAuthState copyWith({
    OfficerModel? officer,
    bool clearOfficer = false,
    List<DepartmentModel>? departments,
    bool? isLoading,
    bool? isRestoring,
    bool? isLoadingDepartments,
    String? error,
    bool clearError = false,
  }) {
    return WorkerAuthState(
      officer: clearOfficer ? null : officer ?? this.officer,
      departments: departments ?? this.departments,
      isLoading: isLoading ?? this.isLoading,
      isRestoring: isRestoring ?? this.isRestoring,
      isLoadingDepartments: isLoadingDepartments ?? this.isLoadingDepartments,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class WorkerAuthNotifier extends StateNotifier<WorkerAuthState> {
  final WorkerRepository repository;
  final WorkerSessionService sessionService;

  WorkerAuthNotifier(this.repository, this.sessionService)
      : super(const WorkerAuthState()) {
    _restore();
  }

  Future<void> _restore() async {
    final officer = await sessionService.restoreSession();
    state = state.copyWith(officer: officer, isRestoring: false);
    await loadDepartments();
  }

  Future<void> loadDepartments() async {
    state = state.copyWith(isLoadingDepartments: true);
    try {
      final departments = await repository.getDepartments();
      state = state.copyWith(departments: departments, isLoadingDepartments: false);
    } catch (_) {
      state = state.copyWith(isLoadingDepartments: false);
    }
  }

  Future<bool> login({required String empId, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final officer = await repository.login(empId: empId, password: password);
      await sessionService.saveSession(officer);
      state = state.copyWith(officer: officer, isLoading: false);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data?['detail']?.toString() ?? 'Login failed. Check your connection.',
      );
      return false;
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Login failed. Check your connection.');
      return false;
    }
  }

  Future<bool> signup({
    required String name,
    required String empId,
    required int departmentId,
    required String password,
    String? contact,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final officer = await repository.signup(
        name: name,
        empId: empId,
        departmentId: departmentId,
        password: password,
        contact: contact,
      );
      await sessionService.saveSession(officer);
      state = state.copyWith(officer: officer, isLoading: false);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data?['detail']?.toString() ?? 'Signup failed. Check your connection.',
      );
      return false;
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Signup failed. Check your connection.');
      return false;
    }
  }

  Future<void> logout() async {
    await sessionService.clearSession();
    state = state.copyWith(clearOfficer: true);
  }
}

final workerAuthProvider = StateNotifierProvider<WorkerAuthNotifier, WorkerAuthState>((ref) {
  final repo = ref.watch(workerRepositoryProvider);
  final session = ref.watch(workerSessionServiceProvider);
  return WorkerAuthNotifier(repo, session);
});
