import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../api/navia_api.dart';
import '../../../providers/explore_provider.dart';
import '../../../theme/navia_theme.dart';

class PlaceListTile extends StatelessWidget {
  const PlaceListTile({
    super.key,
    required this.place,
    required this.onTap,
  });

  final PlaceResult place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: NaviaThemeTokens.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              place.name.isEmpty ? place.placeName : place.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              place.placeName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: NaviaThemeTokens.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class ExploreMap extends StatelessWidget {
  const ExploreMap({
    super.key,
    required this.mapController,
    required this.places,
    required this.initialCenter,
    this.initialZoom = 13,
    this.activeRoute,
  });

  final MapController mapController;
  final List<PlaceResult> places;

  /// The map centre shown when the screen first opens.
  /// Should be derived from the trip's start coordinates or geocoded city.
  final LatLng initialCenter;
  final double initialZoom;

  /// Optional active navigation route overlay from the explore provider.
  final ExploreProvider? activeRoute;

  @override
  Widget build(BuildContext context) {
    // Place search-result markers
    final markers = places
        .where((r) => r.center != null)
        .map((r) => Marker(
              point: LatLng(r.center!.lat, r.center!.lng),
              width: 46,
              height: 46,
              child: Container(
                decoration: BoxDecoration(
                  color: NaviaThemeTokens.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: NaviaThemeTokens.primary.withValues(alpha: 0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(Icons.place, color: Colors.white),
              ),
            ))
        .toList(growable: false);

    // Active route markers (origin + destination)
    final routeMarkers = <Marker>[];
    final routePolylinePoints = <LatLng>[];

    if (activeRoute != null && activeRoute!.hasActiveRoute) {
      final origin = activeRoute!.activeOrigin;
      final dest = activeRoute!.activeDestination;
      final route = activeRoute!.activeRoute;

      if (origin != null) {
        routeMarkers.add(Marker(
          point: origin,
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              color: NaviaThemeTokens.secondary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: NaviaThemeTokens.secondary.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.my_location, color: Colors.white, size: 20),
          ),
        ));
      }

      if (dest != null) {
        routeMarkers.add(Marker(
          point: dest,
          width: 46,
          height: 46,
          child: Container(
            decoration: BoxDecoration(
              color: NaviaThemeTokens.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: NaviaThemeTokens.primary.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.place, color: Colors.white, size: 22),
          ),
        ));
      }

      if (route != null) {
        routePolylinePoints.addAll(route.polyline);
      }
    }

    final allMarkers = [...markers, ...routeMarkers];

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: initialZoom,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.navia.navia_app',
        ),
        if (routePolylinePoints.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: routePolylinePoints,
                color: NaviaThemeTokens.primary,
                strokeWidth: 5,
                borderColor: NaviaThemeTokens.primary.withValues(alpha: 0.25),
                borderStrokeWidth: 10,
              ),
            ],
          ),
        if (allMarkers.isNotEmpty) MarkerLayer(markers: allMarkers),
      ],
    );
  }
}
