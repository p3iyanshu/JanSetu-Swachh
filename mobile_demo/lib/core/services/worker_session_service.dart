import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../data/models/officer_model.dart';

class WorkerSessionService {
  static const _sessionKey = 'jansetu_worker_session';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveSession(OfficerModel officer) async {
    await _storage.write(key: _sessionKey, value: jsonEncode(officer.toJson()));
  }

  Future<OfficerModel?> restoreSession() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null) {
      return null;
    }
    try {
      return OfficerModel.fromJson(Map<String, dynamic>.from(jsonDecode(raw)));
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _sessionKey);
  }
}
