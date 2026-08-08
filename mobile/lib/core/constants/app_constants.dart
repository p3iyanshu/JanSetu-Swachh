import 'dart:io';
import 'package:flutter/foundation.dart';

class AppConstants {
  static String get apiBaseUrl {
    const configuredUrl = String.fromEnvironment(
      'JANSETU_API_BASE_URL',
      defaultValue: '',
    );
    if (configuredUrl.isNotEmpty) {
      return configuredUrl;
    }
    if (kIsWeb) {
      return "http://localhost:8000/api/v1";
    }
    if (Platform.isAndroid) {
      return "http://192.168.31.160:8000/api/v1";
    }
    return "http://localhost:8000/api/v1";
  }

  static const String _apiPathSuffix = '/api/v1';

  /// Backend host root, without the `/api/v1` prefix - needed to resolve
  /// relative media URLs like `/uploads/xxx.jpg` returned by the backend.
  static String get apiRootUrl {
    final base = apiBaseUrl;
    if (base.endsWith(_apiPathSuffix)) {
      return base.substring(0, base.length - _apiPathSuffix.length);
    }
    return base;
  }

  /// Resolves a photo/media path returned by the backend into a fetchable URL.
  /// Already-absolute URLs (e.g. seeded https:// demo images) pass through
  /// unchanged; relative paths like `/uploads/xxx.jpg` get the host prefixed.
  static String resolveMediaUrl(String pathOrUrl) {
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return pathOrUrl;
    }
    return '$apiRootUrl$pathOrUrl';
  }

  static const List<Map<String, dynamic>> categories = [
    {"id": "garbage_overflow", "label": "Garbage", "icon": "trash"},
    {"id": "pothole", "label": "Pothole", "icon": "road"},
    {"id": "water_leakage", "label": "Water Leak", "icon": "water"},
    {"id": "sewage_overflow", "label": "Sewage", "icon": "pipe"},
  ];
}
