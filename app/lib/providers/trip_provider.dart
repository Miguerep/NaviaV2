import 'package:flutter/material.dart';

class TripProvider extends ChangeNotifier {
  String? _destination;
  DateTimeRange? _tripDates;

  String? get destination => _destination;
  DateTimeRange? get tripDates => _tripDates;

  bool get hasTrip => _destination != null && _tripDates != null;

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
    notifyListeners();
  }
}
