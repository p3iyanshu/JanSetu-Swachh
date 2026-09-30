import 'dart:io';
import 'package:flutter/foundation.dart';

class AppConstants {
  /// Server address chosen in the app's "Server address" setting (see
  /// ServerConfig). Wins over the build-time default so the same APK keeps
  /// working when the backend laptop's IP changes (e.g. at the venue).
  static String? serverOverride;

  /// Backend address published in server.json on the JanSetu-Swachh website
  /// (read at startup by ServerConfig). Lets the backend move - e.g. a new
  /// tunnel address - without rebuilding the APK.
  static String? remoteDefault;

  /// Where server.json is published.
  static const String configUrl = String.fromEnvironment(
    'JANSETU_CONFIG_URL',
    defaultValue: 'https://jansetu-swachh.netlify.app/server.json',
  );

  static String get apiBaseUrl {
    final override = serverOverride;
    if (override != null && override.isNotEmpty) {
      return override;
    }
    return defaultApiBaseUrl;
  }

  static String get defaultApiBaseUrl {
    final remote = remoteDefault;
    if (remote != null && remote.isNotEmpty) {
      return remote;
    }
    return buildDefaultApiBaseUrl;
  }

  static String get buildDefaultApiBaseUrl {
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

  static const String appName = 'JanSetu-Swachh';

  /// Citizen-selectable issue types. `group` splits them into the Swachh
  /// (waste & sanitation) segment and the other civic issues JanSetu already
  /// handled. Every id must exist in the backend `CategoryType` enum.
  static const List<Map<String, dynamic>> categories = [
    {"id": "garbage_overflow", "label": "Garbage Pile", "hint": "Overflowing bin or garbage heap", "group": "swachh"},
    {"id": "illegal_dumping", "label": "Dumping Spot", "hint": "Waste dumped on road, lake or empty plot", "group": "swachh"},
    {"id": "missed_pickup", "label": "Missed Pickup", "hint": "Door-to-door collection didn't come", "group": "swachh"},
    {"id": "unsegregated_waste", "label": "Mixed Waste", "hint": "Waste not segregated at source", "group": "swachh"},
    {"id": "waste_burning", "label": "Waste Burning", "hint": "Garbage or plastic being burnt", "group": "swachh"},
    {"id": "public_toilet", "label": "Public Toilet", "hint": "Dirty, locked or no water", "group": "swachh"},
    {"id": "sewage_overflow", "label": "Sewage / Drain", "hint": "Overflowing or blocked drain", "group": "civic"},
    {"id": "water_leakage", "label": "Water Leak", "hint": "Pipeline leak or wastage", "group": "civic"},
    {"id": "pothole", "label": "Pothole", "hint": "Damaged road surface", "group": "civic"},
  ];

  static const Set<String> swachhCategoryIds = {
    'garbage_overflow',
    'illegal_dumping',
    'missed_pickup',
    'unsegregated_waste',
    'waste_burning',
    'public_toilet',
  };

  static bool isSelectableCategory(String? id) =>
      id != null && categories.any((item) => item['id'] == id);

  /// Human-readable label for any backend category id, including ones the
  /// citizen can't pick (e.g. `broken_streetlight` on older tickets).
  static String categoryLabel(String? id) {
    for (final item in categories) {
      if (item['id'] == id) return item['label'] as String;
    }
    switch (id) {
      case 'broken_streetlight':
        return 'Streetlight';
      case 'damaged_public_property':
        return 'Public Property Damage';
      case null:
      case '':
      case 'other':
        return 'Other';
      default:
        return id.replaceAll('_', ' ');
    }
  }
}
