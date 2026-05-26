import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class NaviaApi {
  NaviaApi({required this.baseUrl});
  final String baseUrl;

  Map<String, String> _headers({String? acceptLanguage}) {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
    };
    final lang = acceptLanguage?.trim();
    if (lang != null && lang.isNotEmpty) {
      headers['Accept-Language'] = lang;
    }
    return headers;
  }

  Future<List<PlaceResult>> searchPlaces({
    required String query,
    String? nearLatLng,
    int limit = 5,
    String? acceptLanguage,
  }) async {
    final uri = Uri.parse('$baseUrl/v1/places/search').replace(
      queryParameters: {
        'q': query,
        'limit': '$limit',
        if (nearLatLng != null && nearLatLng.trim().isNotEmpty) 'near': nearLatLng,
      },
    );
    
    final res = await http
        .get(uri, headers: _headers(acceptLanguage: acceptLanguage))
        .timeout(const Duration(seconds: 15));
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
    String? acceptLanguage,
  }) async {
    final uri = Uri.parse('$baseUrl/v1/osm/route').replace(
      queryParameters: {
        'from': '${from.lat},${from.lng}',
        'to': '${to.lat},${to.lng}',
      },
    );
    
    final res = await http
        .get(uri, headers: _headers(acceptLanguage: acceptLanguage))
        .timeout(const Duration(seconds: 15));
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

  Future<Trip> createTrip({
    required CreateTripRequest payload,
    String? acceptLanguage,
  }) async {
    final uri = Uri.parse('$baseUrl/v1/trips');
    final res = await http
        .post(
          uri,
          headers: _headers(acceptLanguage: acceptLanguage),
          body: jsonEncode(payload.toJson()),
        )
        .timeout(const Duration(seconds: 20));
    final body = utf8.decode(res.bodyBytes);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiError(res.statusCode, body);
    }

    final json = jsonDecode(body);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Invalid createTrip response format');
    }
    final tripJson = json['trip'];
    if (tripJson is! Map<String, dynamic>) {
      throw const FormatException('Invalid createTrip response payload');
    }
    return Trip.fromJson(tripJson);
  }

  Future<Trip> updateTripPreferences({
    required String tripId,
    required List<String> interests,
    required String pace,
    String? acceptLanguage,
  }) async {
    final uri = Uri.parse('$baseUrl/v1/trips/$tripId/preferences');
    final res = await http
        .patch(
          uri,
          headers: _headers(acceptLanguage: acceptLanguage),
          body: jsonEncode({'interests': interests, 'pace': pace}),
        )
        .timeout(const Duration(seconds: 20));
    final body = utf8.decode(res.bodyBytes);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiError(res.statusCode, body);
    }

    final json = jsonDecode(body);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Invalid updateTripPreferences response format');
    }
    final tripJson = json['trip'];
    if (tripJson is! Map<String, dynamic>) {
      throw const FormatException('Invalid updateTripPreferences response payload');
    }
    return Trip.fromJson(tripJson);
  }


  Future<DayPlan> getDayPlan({
    required String tripId,
    required DateTime day,
    String? acceptLanguage,
  }) async {
    final yyyy = day.year.toString().padLeft(4, '0');
    final mm = day.month.toString().padLeft(2, '0');
    final dd = day.day.toString().padLeft(2, '0');
    final dateIso = '$yyyy-$mm-$dd';
    final uri = Uri.parse('$baseUrl/v1/itinerary/$tripId/$dateIso');

    final res = await http
        .get(uri, headers: _headers(acceptLanguage: acceptLanguage))
        .timeout(const Duration(seconds: 20));
    final body = utf8.decode(res.bodyBytes);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiError(res.statusCode, body);
    }

    final json = jsonDecode(body);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Invalid itinerary response format');
    }
    final planJson = json['plan'];
    if (planJson is! Map<String, dynamic>) {
      throw const FormatException('Invalid itinerary response payload');
    }
    return DayPlan.fromJson(planJson);
  }

  Future<NarrationSummaryResponse> getNarrationSummary({
    required NarrationSummaryRequest payload,
    String? acceptLanguage,
  }) async {
    final uri = Uri.parse('$baseUrl/v1/narration/summary');
    final res = await http
        .post(
          uri,
          headers: _headers(acceptLanguage: acceptLanguage),
          body: jsonEncode(payload.toJson()),
        )
        .timeout(const Duration(seconds: 20));
    final body = utf8.decode(res.bodyBytes);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiError(res.statusCode, body);
    }

    final json = jsonDecode(body);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Invalid narration response format');
    }
    return NarrationSummaryResponse.fromJson(json);
  }

  Future<NarrationAudioResult> getNarrationAudio({
    required NarrationSummaryRequest payload,
    String? acceptLanguage,
  }) async {
    final uri = Uri.parse('$baseUrl/v1/narration/audio');
    final res = await http
        .post(
          uri,
          headers: _headers(acceptLanguage: acceptLanguage),
          body: jsonEncode(payload.toJson()),
        )
        .timeout(const Duration(seconds: 20));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = utf8.decode(res.bodyBytes);
      throw ApiError(res.statusCode, body);
    }

    final contentType = res.headers['content-type'] ?? '';
    if (contentType.contains('audio/mpeg')) {
      return NarrationAudioResult(audioBytes: res.bodyBytes);
    }

    // Fallback text
    final body = utf8.decode(res.bodyBytes);
    final json = jsonDecode(body);
    if (json is Map<String, dynamic>) {
      return NarrationAudioResult(textFallback: NarrationSummaryResponse.fromJson(json).text);
    }
    throw const FormatException('Invalid narration fallback response format');
  }

  Future<void> regenerateDayPlan({
    required String tripId,
    required DateTime date,
    String? acceptLanguage,
  }) async {
    final uri = Uri.parse('$baseUrl/v1/itinerary/$tripId/regenerate');
    final yyyy = date.year.toString().padLeft(4, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    
    final res = await http.post(
      uri,
      headers: _headers(acceptLanguage: acceptLanguage),
      body: jsonEncode({'date': '$yyyy-$mm-$dd'}),
    ).timeout(const Duration(seconds: 30));
    
    final body = utf8.decode(res.bodyBytes);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiError(res.statusCode, body);
    }
  }

  Stream<ChatEvent> sendChatMessage({
    required String tripId,
    required String userMessage,
    required DateTime activeDate,
    String? acceptLanguage,
  }) async* {
    final uri = Uri.parse('$baseUrl/v1/chat');
    final req = http.Request('POST', uri);
    req.headers.addAll(_headers(acceptLanguage: acceptLanguage));
    
    final yyyy = activeDate.year.toString().padLeft(4, '0');
    final mm = activeDate.month.toString().padLeft(2, '0');
    final dd = activeDate.day.toString().padLeft(2, '0');
    
    req.body = jsonEncode({
      'tripId': tripId,
      'userMessage': userMessage,
      'activeDate': '$yyyy-$mm-$dd',
    });

    final client = http.Client();
    try {
      final res = await client.send(req);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        final bodyBytes = await res.stream.toBytes();
        throw ApiError(res.statusCode, utf8.decode(bodyBytes));
      }

      String currentEvent = '';
      await for (final line in res.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (line.isEmpty) continue;
        if (line.startsWith('event: ')) {
          currentEvent = line.substring(7).trim();
        } else if (line.startsWith('data: ')) {
          final dataStr = line.substring(6).trim();
          final dataJson = jsonDecode(dataStr);
          if (currentEvent == 'message.delta' || currentEvent == 'message.final') {
            yield ChatEventText(dataJson['text'] as String, isFinal: currentEvent == 'message.final');
          } else if (currentEvent == 'actions') {
            yield ChatEventActions(dataJson['actions'] as List<dynamic>);
          }
        }
      }
    } finally {
      client.close();
    }
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
  RouteResult({
    required this.distanceMeters,
    required this.durationSeconds,
    this.polyline = const [],
  });

  final double? distanceMeters;
  final double? durationSeconds;
  /// Decoded polyline points from the GeoJSON geometry.
  final List<LatLng> polyline;

  factory RouteResult.fromJson(Map<String, dynamic> json) {
    // Parse GeoJSON LineString coordinates [[lng,lat], ...]
    final geometry = json['geometry'];
    final coords = (geometry is Map<String, dynamic>)
        ? (geometry['coordinates'] as List<dynamic>?)
        : null;
    final polyline = coords
            ?.whereType<List<dynamic>>()
            .map((c) {
              if (c.length < 2) return null;
              final lng = (c[0] as num?)?.toDouble();
              final lat = (c[1] as num?)?.toDouble();
              if (lat == null || lng == null) return null;
              return LatLng(lat, lng);
            })
            .whereType<LatLng>()
            .toList(growable: false) ??
        const [];
    return RouteResult(
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
      durationSeconds: (json['durationSeconds'] as num?)?.toDouble(),
      polyline: polyline,
    );
  }
}

class CreateTripRequest {
  CreateTripRequest({
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.tripDuration,
    required this.interests,
    required this.pace,
    this.startLat,
    this.startLng,
  });

  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final int tripDuration;
  final List<String> interests;
  final String pace;
  final double? startLat;
  final double? startLng;

  Map<String, dynamic> toJson() => {
        'destination': destination,
        'startDate': _dateOnly(startDate),
        'endDate': _dateOnly(endDate),
        'tripDuration': tripDuration,
        'interests': interests,
        'pace': pace,
        if (startLat != null) 'startLat': startLat,
        if (startLng != null) 'startLng': startLng,
      };

  static String _dateOnly(DateTime dt) {
    final yyyy = dt.year.toString().padLeft(4, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }
}

class Trip {
  Trip({
    required this.id,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.tripDuration,
    required this.interests,
    required this.pace,
    this.startLat,
    this.startLng,
  });

  final String id;
  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final int? tripDuration;
  final List<String> interests;
  final String? pace;
  final double? startLat;
  final double? startLng;

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: (json['id'] ?? '').toString(),
      destination: (json['destination'] ?? '').toString(),
      startDate: DateTime.tryParse((json['startDate'] ?? '').toString()) ??
          DateTime(1970),
      endDate:
          DateTime.tryParse((json['endDate'] ?? '').toString()) ?? DateTime(1970),
      tripDuration: (json['tripDuration'] as num?)?.toInt(),
      interests: (json['interests'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .where((s) => s.trim().isNotEmpty)
              .toList(growable: false) ??
          const [],
      pace: (json['pace'] as String?)?.toString(),
      startLat: (json['startLat'] as num?)?.toDouble(),
      startLng: (json['startLng'] as num?)?.toDouble(),
    );
  }
}

class DayPlan {
  DayPlan({
    required this.id,
    required this.tripId,
    required this.date,
    required this.stops,
  });

  final String id;
  final String tripId;
  final DateTime date;
  final List<Stop> stops;

  factory DayPlan.fromJson(Map<String, dynamic> json) {
    final stopsJson = json['stops'];
    return DayPlan(
      id: (json['id'] ?? '').toString(),
      tripId: (json['tripId'] ?? '').toString(),
      date: DateTime.tryParse((json['date'] ?? '').toString()) ?? DateTime(1970),
      stops: (stopsJson is List)
          ? stopsJson
              .whereType<Map<String, dynamic>>()
              .map(Stop.fromJson)
              .toList(growable: false)
          : const [],
    );
  }
}

class Stop {
  Stop({
    required this.id,
    required this.ordinal,
    required this.title,
    this.subtitle,
    this.startTimeLocal,
  });

  final String id;
  final int ordinal;
  final String title;
  final String? subtitle;
  final String? startTimeLocal;

  factory Stop.fromJson(Map<String, dynamic> json) {
    return Stop(
      id: (json['id'] ?? '').toString(),
      ordinal: (json['ordinal'] as num?)?.toInt() ?? 0,
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] as String?)?.toString(),
      startTimeLocal: (json['startTimeLocal'] as String?)?.toString(),
    );
  }
}

class NarrationSummaryRequest {
  NarrationSummaryRequest({
    required this.tripId,
    required this.stopTitle,
    this.stopSubtitle,
  });

  final String tripId;
  final String stopTitle;
  final String? stopSubtitle;

  Map<String, dynamic> toJson() => {
        'tripId': tripId,
        'stopTitle': stopTitle,
        if (stopSubtitle != null) 'stopSubtitle': stopSubtitle,
      };
}

class NarrationSummaryResponse {
  NarrationSummaryResponse({required this.text});
  final String text;

  factory NarrationSummaryResponse.fromJson(Map<String, dynamic> json) {
    return NarrationSummaryResponse(text: (json['text'] ?? '').toString());
  }
}

sealed class ChatEvent {}

class ChatEventText extends ChatEvent {
  ChatEventText(this.text, {this.isFinal = false});
  final String text;
  final bool isFinal;
}

class ChatEventActions extends ChatEvent {
  ChatEventActions(this.actions);
  final List<dynamic> actions;
}

class NarrationAudioResult {
  NarrationAudioResult({this.audioBytes, this.textFallback});
  final Uint8List? audioBytes;
  final String? textFallback;
}
