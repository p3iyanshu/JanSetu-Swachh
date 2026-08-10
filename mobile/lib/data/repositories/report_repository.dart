import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../models/report_model.dart';

class ReportRepository {
  final ApiClient _apiClient;

  ReportRepository(this._apiClient);

  Future<ReportModel> submitReport(ReportModel report) async {
    try {
      final response = await _apiClient.dio.post('/reports/', data: report.toJson());
      return ReportModel.fromJson(response.data);
    } catch (e) {
      // Offline fallback stub for step 1 scaffolding
      return report;
    }
  }

  Future<String> uploadPhoto(String localImagePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(localImagePath),
    });
    final response = await _apiClient.dio.post(
      '/reports/upload-photo',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return Map<String, dynamic>.from(response.data as Map)['photo_url'] as String;
  }

  Future<Map<String, dynamic>> analyzeIssueImage(String imagePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(imagePath),
    });

    final response = await _apiClient.dio.post(
      '/ai/analyze-issue',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<List<ReportModel>> getReports() async {
    try {
      final response = await _apiClient.dio.get('/reports/');
      return (response.data as List).map((e) => ReportModel.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<ReportModel> submitFeedback({
    required int reportId,
    required bool satisfied,
    String? comment,
  }) async {
    final response = await _apiClient.dio.post(
      '/reports/$reportId/feedback',
      data: {'satisfied': satisfied, 'comment': comment},
    );
    return ReportModel.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<ReportModel> cancelReport({
    required int reportId,
    String? reason,
  }) async {
    final response = await _apiClient.dio.post(
      '/reports/$reportId/cancel',
      data: {'reason': reason},
    );
    return ReportModel.fromJson(Map<String, dynamic>.from(response.data as Map));
  }
}
