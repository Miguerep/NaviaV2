import 'package:flutter/material.dart';

class TripProvider extends ChangeNotifier {
  String? _destination;
  DateTimeRange? _tripDates;

  // Step-one fields
  int _tripDuration = 5;
  final Set<String> _interests = {};
  String _pace = 'Relaxed';

  String? get destination => _destination;
  DateTimeRange? get tripDates => _tripDates;

  int get tripDuration => _tripDuration;
  Set<String> get interests => Set.unmodifiable(_interests);
  String get pace => _pace;

  bool get hasTrip => _destination != null && _tripDates != null;

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
    _destination = null;
    _tripDates = null;
    _tripDuration = 5;
    _interests.clear();
    _pace = 'Relaxed';
    notifyListeners();
  }
}

