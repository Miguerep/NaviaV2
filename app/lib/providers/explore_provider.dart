import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../api/navia_api.dart';

class ExploreProvider extends ChangeNotifier {
  ExploreProvider(this.api);
  
  final NaviaApi api;
  GeoPoint? _userLocation;

  bool _loading = false;
  String? _error;
  List<PlaceResult> _results = [];

  // ── Active walking route (set from itinerary "walk" button) ──────────
  RouteResult? _activeRoute;
  LatLng? _activeOrigin;
  LatLng? _activeDestination;
  String? _activeDestinationName;

  RouteResult? get activeRoute => _activeRoute;
  LatLng? get activeOrigin => _activeOrigin;
  LatLng? get activeDestination => _activeDestination;
  String? get activeDestinationName => _activeDestinationName;
  bool get hasActiveRoute => _activeRoute != null;
  
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

  /// Set a pre-computed walking route to be displayed on the explore map.
  /// Called from the itinerary screen when the user taps "walk".
  void setActiveRoute({
    required RouteResult route,
    required LatLng origin,
    required LatLng destination,
    required String destinationName,
  }) {
    _activeRoute = route;
    _activeOrigin = origin;
    _activeDestination = destination;
    _activeDestinationName = destinationName;
    // Clear search results so the route overlay is prominent
    _results = [];
    _error = null;
    notifyListeners();
  }

  /// Clear the active navigation route.
  void clearActiveRoute() {
    if (_activeRoute == null) return;
    _activeRoute = null;
    _activeOrigin = null;
    _activeDestination = null;
    _activeDestinationName = null;
    notifyListeners();
  }

  Future<void> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    
    // Clear any active route when doing a new search
    _activeRoute = null;
    _activeOrigin = null;
    _activeDestination = null;
    _activeDestinationName = null;

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
