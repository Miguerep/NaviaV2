import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TripProvider extends ChangeNotifier {
  static const _kTripIdKey = 'navia_trip_id';

  String? _tripId;
  String? _destination;
  DateTimeRange? _tripDates;

  // Step-one fields
  int _tripDuration = 5;
  final Set<String> _interests = {};
  String _pace = 'Relaxed';

  double? _startLat;
  double? _startLng;
  String? _acceptLanguage;

  String? get tripId => _tripId;
  String? get destination => _destination;
  DateTimeRange? get tripDates => _tripDates;

  int get tripDuration => _tripDuration;
  Set<String> get interests => Set.unmodifiable(_interests);
  String get pace => _pace;

  double? get startLat => _startLat;
  double? get startLng => _startLng;
  String? get acceptLanguage => _acceptLanguage;

  bool get hasTrip => _tripId != null;

  Future<void> restoreTripIdFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getString(_kTripIdKey);
      if (v == null || v.trim().isEmpty) return;
      if (_tripId == v.trim()) return;
      _tripId = v.trim();
      notifyListeners();
    } catch (_) {
      // Best-effort: persistence should not block startup.
    }
  }

  // --- Step-one setters ---

  void setTripDuration(int days) {
    _tripDuration = days.clamp(1, 30);
    notifyListeners();
  }

  void toggleInterest(String interest) {
    if (_interests.contains(interest)) {
      _interests.remove(interest);
    } else {
      _interests.add(interest);
    }
    notifyListeners();
  }

  void setPace(String pace) {
    _pace = pace;
    notifyListeners();
  }

  void setTripId(String? tripId) {
    _tripId = (tripId == null || tripId.trim().isEmpty) ? null : tripId.trim();
    _persistTripId();
    notifyListeners();
  }

  Future<void> _persistTripId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_tripId == null) {
        await prefs.remove(_kTripIdKey);
      } else {
        await prefs.setString(_kTripIdKey, _tripId!);
      }
    } catch (_) {}
  }

  void setStartLocation({double? lat, double? lng}) {
    _startLat = lat;
    _startLng = lng;
    notifyListeners();
  }

  void setAcceptLanguage(String? languageTag) {
    final v = languageTag?.trim();
    _acceptLanguage = (v == null || v.isEmpty) ? null : v;
    notifyListeners();
  }

  Future<void> initLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      setStartLocation(lat: pos.latitude, lng: pos.longitude);
    } catch (_) {
      // Best-effort: location is optional for MVP flows.
    }
  }

  // --- Existing setters ---

  void setDestination(String dest) {
    _destination = dest;
    notifyListeners();
  }

  void setDates(DateTimeRange dates) {
    _tripDates = dates;
    notifyListeners();
  }

  void reset() {
    _tripId = null;
    _destination = null;
    _tripDates = null;
    _tripDuration = 5;
    _interests.clear();
    _pace = 'Relaxed';
    _startLat = null;
    _startLng = null;
    _persistTripId();
    notifyListeners();
  }
}

