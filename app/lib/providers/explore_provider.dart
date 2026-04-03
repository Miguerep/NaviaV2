import 'package:flutter/material.dart';
import '../api/navia_api.dart';

class ExploreProvider extends ChangeNotifier {
  ExploreProvider(this.api);
  
  final NaviaApi api;
  GeoPoint? _userLocation;

  bool _loading = false;
  String? _error;
  List<PlaceResult> _results = [];
  
  bool get loading => _loading;
  String? get error => _error;
  List<PlaceResult> get results => _results;

  void setUserLocation(GeoPoint? location) {
    _userLocation = location;
  }

  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  Future<void> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final near = _userLocation == null
          ? null
          : '${_userLocation!.lat},${_userLocation!.lng}';
      _results = await api.searchPlaces(query: q, nearLatLng: near);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<RouteResult?> getRouteToPlace(PlaceResult p) async {
    if (p.center == null) return null;
    final from = _userLocation ?? GeoPoint(lat: 48.8566, lng: 2.3522);
    try {
      return await api.getRouteWalking(from: from, to: p.center!);
    } catch (e) {
      return null; // Don't broadcast error to whole screen for a single bottom sheet
    }
  }
}
