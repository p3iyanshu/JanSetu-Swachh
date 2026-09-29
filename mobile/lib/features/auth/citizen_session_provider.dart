import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The logged-in citizen, as returned by `/auth/verify-otp`. Kept so reports
/// are filed under the citizen's account (for "My Tickets" and Swachh
/// points) and survive an app restart.
class CitizenSession {
  final int userId;
  final String phone;

  const CitizenSession({required this.userId, required this.phone});

  Map<String, dynamic> toJson() => {'user_id': userId, 'phone': phone};

  factory CitizenSession.fromJson(Map<String, dynamic> json) => CitizenSession(
        userId: json['user_id'] as int,
        phone: json['phone'] as String,
      );
}

class CitizenSessionNotifier extends StateNotifier<CitizenSession?> {
  static const _sessionKey = 'jansetu_citizen_session';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  CitizenSessionNotifier() : super(null) {
    _restore();
  }

  Future<void> _restore() async {
    try {
      final raw = await _storage.read(key: _sessionKey);
      if (raw == null || state != null) return;
      state = CitizenSession.fromJson(Map<String, dynamic>.from(jsonDecode(raw)));
    } catch (_) {
      // Corrupt or unreadable session - behave as logged out.
    }
  }

  Future<void> login({required int userId, required String phone}) async {
    final session = CitizenSession(userId: userId, phone: phone);
    state = session;
    try {
      await _storage.write(key: _sessionKey, value: jsonEncode(session.toJson()));
    } catch (_) {}
  }

  Future<void> logout() async {
    state = null;
    try {
      await _storage.delete(key: _sessionKey);
    } catch (_) {}
  }
}

final citizenSessionProvider =
    StateNotifierProvider<CitizenSessionNotifier, CitizenSession?>((ref) => CitizenSessionNotifier());
