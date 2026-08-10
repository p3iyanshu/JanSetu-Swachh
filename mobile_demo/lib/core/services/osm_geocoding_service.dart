import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class OSMPlace {
  final LatLng point;
  final String address;

  const OSMPlace({
    required this.point,
    required this.address,
  });
}

class OSMGeocodingService {
  static const _baseUrl = 'https://nominatim.openstreetmap.org';
  static const _headers = {
    'User-Agent': 'JanSetuCitizenApp/1.0 com.example.jansetu_mobile',
    'Accept': 'application/json',
  };

  static Future<OSMPlace?> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.parse('$_baseUrl/search').replace(
      queryParameters: {
        'format': 'jsonv2',
        'limit': '1',
        'addressdetails': '1',
        'q': trimmed,
      },
    );

    final response =
        await http.get(uri, headers: _headers).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception('Search failed with status ${response.statusCode}');
    }

    final results = jsonDecode(response.body) as List<dynamic>;
    if (results.isEmpty) return null;

    final first = results.first as Map<String, dynamic>;
    return OSMPlace(
      point: LatLng(
        double.parse(first['lat'] as String),
        double.parse(first['lon'] as String),
      ),
      address: (first['display_name'] as String?) ?? trimmed,
    );
  }

  static Future<String> reverse(double latitude, double longitude) async {
    final uri = Uri.parse('$_baseUrl/reverse').replace(
      queryParameters: {
        'format': 'jsonv2',
        'lat': latitude.toString(),
        'lon': longitude.toString(),
      },
    );

    final response =
        await http.get(uri, headers: _headers).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception('Reverse geocoding failed with status ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['display_name'] as String?) ??
        'Selected Location (${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)})';
  }
}
