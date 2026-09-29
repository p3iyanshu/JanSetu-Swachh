import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';

class CitizenImpact {
  final int points;
  final String level;
  final String? nextLevelName;
  final int? pointsToNextLevel;
  final int reportsFiled;
  final int swachhReports;
  final int resolved;
  final int verified;

  const CitizenImpact({
    required this.points,
    required this.level,
    this.nextLevelName,
    this.pointsToNextLevel,
    required this.reportsFiled,
    required this.swachhReports,
    required this.resolved,
    required this.verified,
  });

  factory CitizenImpact.fromJson(Map<String, dynamic> json) {
    final next = json['next_level'] as Map?;
    return CitizenImpact(
      points: json['points'] as int? ?? 0,
      level: json['level'] as String? ?? 'Swachh Starter',
      nextLevelName: next?['name'] as String?,
      pointsToNextLevel: next?['points_needed'] as int?,
      reportsFiled: json['reports_filed'] as int? ?? 0,
      swachhReports: json['swachh_reports'] as int? ?? 0,
      resolved: json['resolved'] as int? ?? 0,
      verified: json['verified'] as int? ?? 0,
    );
  }
}

class WasteItemScanResult {
  final bool detected;
  final String? label;
  final String? streamId;
  final String message;

  const WasteItemScanResult({
    required this.detected,
    this.label,
    this.streamId,
    required this.message,
  });

  factory WasteItemScanResult.fromJson(Map<String, dynamic> json) => WasteItemScanResult(
        detected: json['detected'] == true,
        label: json['label'] as String?,
        streamId: json['stream'] as String?,
        message: json['message'] as String? ?? '',
      );
}

class CollectionLogModel {
  final int id;
  final String householdCode;
  final String ward;
  final String status;
  final String? note;
  final String createdAt;

  const CollectionLogModel({
    required this.id,
    required this.householdCode,
    required this.ward,
    required this.status,
    this.note,
    required this.createdAt,
  });

  factory CollectionLogModel.fromJson(Map<String, dynamic> json) => CollectionLogModel(
        id: json['id'] as int,
        householdCode: json['household_code'] as String,
        ward: json['ward'] as String,
        status: json['status'] as String,
        note: json['note'] as String?,
        createdAt: json['created_at'] as String,
      );

  /// Backend timestamps are naive UTC.
  DateTime get createdAtLocal => DateTime.parse('${createdAt}Z').toLocal();
}

class SwachhRepository {
  final ApiClient _apiClient;

  SwachhRepository(this._apiClient);

  Future<CitizenImpact> getCitizenImpact(int userId) async {
    final response = await _apiClient.dio.get('/swachh/citizens/$userId/impact');
    return CitizenImpact.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<WasteItemScanResult> classifyWasteItem(String imagePath) async {
    final formData = FormData.fromMap({'file': await MultipartFile.fromFile(imagePath)});
    final response = await _apiClient.dio.post(
      '/swachh/classify-item',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return WasteItemScanResult.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<CollectionLogModel> logCollection({
    required String householdCode,
    required String ward,
    required String status,
    String? note,
    double? latitude,
    double? longitude,
    int? officerId,
  }) async {
    final response = await _apiClient.dio.post('/swachh/collections', data: {
      'household_code': householdCode,
      'ward': ward,
      'status': status,
      if (note != null && note.isNotEmpty) 'note': note,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (officerId != null) 'officer_id': officerId,
    });
    return CollectionLogModel.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<List<CollectionLogModel>> getCollections({required int officerId, int limit = 100}) async {
    final response = await _apiClient.dio.get(
      '/swachh/collections',
      queryParameters: {'officer_id': officerId, 'limit': limit},
    );
    return (response.data as List)
        .map((item) => CollectionLogModel.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }
}
