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
        ...?switch (nearLatLng) {
          null => null,
          final near => {'near': near},
        },
      },
    );
    final res = await http.get(uri);
    final body = utf8.decode(res.bodyBytes);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiError(res.statusCode, body);
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    final results = (json['results'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PlaceResult.fromJson)
        .toList(growable: false);
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
    final res = await http.get(uri);
    final body = utf8.decode(res.bodyBytes);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiError(res.statusCode, body);
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    return RouteResult.fromJson(json);
  }
}

class ApiError implements Exception {
  ApiError(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'ApiError($statusCode): $body';
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

  factory PlaceResult.fromJson(Map<String, dynamic> json) {
    final center = json['center'];
    return PlaceResult(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      placeName: (json['placeName'] ?? '').toString(),
      center: center is Map<String, dynamic>
          ? GeoPoint(
              lat: (center['lat'] as num?)?.toDouble() ?? 0,
              lng: (center['lng'] as num?)?.toDouble() ?? 0,
            )
          : null,
      categories: (json['categories'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .where((s) => s.trim().isNotEmpty)
          .toList(growable: false),
    );
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

