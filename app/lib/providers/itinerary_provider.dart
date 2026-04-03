import 'package:flutter/material.dart';

import '../api/navia_api.dart';

class ItineraryProvider extends ChangeNotifier {
  ItineraryProvider({required this.api});

  final NaviaApi api;

  bool _loading = false;
  String? _error;
  DayPlan? _plan;
  DateTime _activeDay = DateTime.now();

  bool get loading => _loading;
  String? get error => _error;
  DayPlan? get plan => _plan;
  DateTime get activeDay => _activeDay;

  void setActiveDay(DateTime day) {
    _activeDay = DateTime(day.year, day.month, day.day);
    notifyListeners();
  }

  Future<void> loadDay({
    required String tripId,
    required DateTime day,
    String? acceptLanguage,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _activeDay = DateTime(day.year, day.month, day.day);
      _plan = await api.getDayPlan(
        tripId: tripId,
        day: _activeDay,
        acceptLanguage: acceptLanguage,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}

