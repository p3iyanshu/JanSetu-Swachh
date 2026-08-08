import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../models/department_model.dart';
import '../models/officer_model.dart';
import '../models/report_model.dart';

class WorkerRepository {
  final ApiClient _apiClient;

  WorkerRepository(this._apiClient);

  Future<List<DepartmentModel>> getDepartments() async {
    final response = await _apiClient.dio.get('/departments/');
    return (response.data as List)
        .map((e) => DepartmentModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<OfficerModel> signup({
    required String name,
    required String empId,
    required int departmentId,
    required String password,
    String? contact,
  }) async {
    final response = await _apiClient.dio.post(
      '/admin/signup',
      data: {
        'name': name,
        'emp_id': empId,
        'department_id': departmentId,
        'password': password,
        'contact': contact,
      },
    );
    return OfficerModel.fromJson(Map<String, dynamic>.from(response.data));
  }

  Future<OfficerModel> login({required String empId, required String password}) async {
    final response = await _apiClient.dio.post(
      '/admin/login',
      data: {'emp_id': empId, 'password': password},
    );
    return OfficerModel.fromJson(Map<String, dynamic>.from(response.data));
  }

  Future<List<ReportModel>> getAssignedTickets(int officerId) async {
    final response = await _apiClient.dio.get('/admin/reports/assigned-to/$officerId');
    return (response.data as List)
        .map((e) => ReportModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<ReportModel>> getDepartmentTickets(int departmentId) async {
    final response = await _apiClient.dio.get('/admin/reports/department/$departmentId');
    return (response.data as List)
        .map((e) => ReportModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<ReportModel> startWork({required int reportId, required int officerId}) async {
    final response = await _apiClient.dio.post(
      '/admin/reports/$reportId/start',
      data: {'officer_id': officerId},
    );
    return ReportModel.fromJson(Map<String, dynamic>.from(response.data));
  }

  Future<ReportModel> resolveTicket({
    required int reportId,
    required int officerId,
    required double latitude,
    required double longitude,
    required String photoPath,
    DateTime? capturedAt,
  }) async {
    final formData = FormData.fromMap({
      'officer_id': officerId,
      'latitude': latitude,
      'longitude': longitude,
      if (capturedAt != null) 'captured_at': capturedAt.toIso8601String(),
      'after_photo': await MultipartFile.fromFile(photoPath),
    });
    final response = await _apiClient.dio.post(
      '/admin/reports/$reportId/resolve',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return ReportModel.fromJson(Map<String, dynamic>.from(response.data));
  }
}
