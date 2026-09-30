import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_constants.dart';

/// Persists the backend server address the user sets in the app, so one
/// APK can be pointed at whichever laptop/server is running the backend.
class ServerConfig {
  static const _key = 'jansetu_server_base_url';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<void> load() async {
    try {
      AppConstants.serverOverride = await _storage.read(key: _key);
    } catch (_) {
      AppConstants.serverOverride = null;
    }
    await _loadRemoteDefault();
  }

  /// Reads the published server.json (see AppConstants.configUrl). Never
  /// throws and gives up after a few seconds, so the app still starts offline.
  static Future<void> _loadRemoteDefault() async {
    try {
      final response = await Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 3),
        responseType: ResponseType.json,
      )).get(AppConstants.configUrl);
      final data = response.data;
      final url = data is Map ? data['api_base_url'] : null;
      if (url is String && (url.startsWith('https://') || url.startsWith('http://'))) {
        AppConstants.remoteDefault = url.replaceAll(RegExp(r'/+$'), '');
      }
    } catch (_) {
      // Offline or not published - keep the built-in default.
    }
  }

  /// Accepts "192.168.1.5", "192.168.1.5:8000", "http://host:8000" or a full
  /// ".../api/v1" URL and normalises it to the API base URL. Returns null if
  /// the input can't be a valid address.
  static String? normalize(String input) {
    var value = input.trim();
    if (value.isEmpty) return null;
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'http://$value';
    }
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return null;
    final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 8000);
    final path = uri.path.endsWith('/api/v1')
        ? uri.path
        : '${uri.path.replaceAll(RegExp(r'/+$'), '')}/api/v1';
    return Uri(scheme: uri.scheme, host: uri.host, port: port, path: path).toString();
  }

  static Future<void> save(String baseUrl) async {
    AppConstants.serverOverride = baseUrl;
    try {
      await _storage.write(key: _key, value: baseUrl);
    } catch (_) {}
  }

  static Future<void> reset() async {
    AppConstants.serverOverride = null;
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  }
}
