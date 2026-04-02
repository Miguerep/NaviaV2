import 'dart:convert';
import 'package:http/http.dart' as http;

class NaviaApi {
  NaviaApi({required this.baseUrl});
  final String baseUrl;

  Future<List<PlaceResult>> searchPlaces({
    required String query,
    String? nearLatLng,
    int limit = 5,
  }) async {
    final uri = Uri.parse('$baseUrl/v1/places/search').replace(
      queryParameters: {
        'q': query,
        'limit': '$limit',
        'near': ?nearLatLng,
      },
    );
    
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    final body = utf8.decode(res.bodyBytes);
    
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiError(res.statusCode, body);
    }
    
    final json = jsonDecode(body);
    if (json is! Map<String, dynamic> || !json.containsKey('results')) {
      return [];
    }
    
    final results = (json['results'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(PlaceResult.fromJson)
            .whereType<PlaceResult>()
            .toList(growable: false) ?? [];
            
    return results;
  }

  Future<RouteResult> getRouteWalking({
    required GeoPoint from,
    required GeoPoint to,
  }) async {
    final uri = Uri.parse('$baseUrl/v1/route').replace(
      queryParameters: {
        'from': '${from.lat},${from.lng}',
        'to': '${to.lat},${to.lng}',
      },
    );
    
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    final body = utf8.decode(res.bodyBytes);
    
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiError(res.statusCode, body);
    }
    
    final json = jsonDecode(body);
    if (json is! Map<String, dynamic>) {
      throw FormatException('Invalid route response format');
    }
    
    return RouteResult.fromJson(json);
  }
}

class ApiError implements Exception {
  ApiError(this.statusCode, this.body);
  final int statusCode;
  final String body;

  @override
  String toString() {
    try {
      final json = jsonDecode(body);
      if (json is Map && json.containsKey('error')) {
        return json['error'].toString();
      }
    } catch (_) {}
    return 'ApiError($statusCode): Something went wrong';
  }
}

class PlaceResult {
  PlaceResult({
    required this.id,
    required this.name,
    required this.placeName,
    required this.center,
    required this.categories,
  });

  final String id;
  final String name;
  final String placeName;
  final GeoPoint? center;
  final List<String> categories;

  static PlaceResult? fromJson(Map<String, dynamic> json) {
    try {
      final centerMap = json['center'];
      GeoPoint? center;
      if (centerMap is Map<String, dynamic>) {
        final lat = (centerMap['lat'] as num?)?.toDouble() ?? 0.0;
        final lng = (centerMap['lng'] as num?)?.toDouble() ?? 0.0;
        center = GeoPoint(lat: lat, lng: lng);
      }

      return PlaceResult(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        placeName: (json['placeName'] ?? '').toString(),
        center: center,
        categories: (json['categories'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .where((s) => s.trim().isNotEmpty)
                .toList(growable: false) ?? const [],
      );
    } catch (_) {
      return null; // Skip malformed places
    }
  }
}

class GeoPoint {
  GeoPoint({required this.lat, required this.lng});
  final double lat;
  final double lng;
}

class RouteResult {
  RouteResult({required this.distanceMeters, required this.durationSeconds});

  final double? distanceMeters;
  final double? durationSeconds;

  factory RouteResult.fromJson(Map<String, dynamic> json) {
    return RouteResult(
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
      durationSeconds: (json['durationSeconds'] as num?)?.toDouble(),
    );
  }
}
