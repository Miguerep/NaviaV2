import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../api/navia_api.dart';
import '../../../config/app_env.dart';
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
  });

  final MapController mapController;
  final List<PlaceResult> places;

  @override
  Widget build(BuildContext context) {
    final canShowMap = AppEnv.mapboxPublicToken.trim().isNotEmpty;

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

    if (!canShowMap) {
      return Container(
        color: NaviaThemeTokens.surfaceContainerHighest,
        child: Center(
          child: Text(
            'To show the map, run the app with:\n--dart-define=MAPBOX_PUBLIC_TOKEN=YOUR_TOKEN',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: NaviaThemeTokens.onSurfaceVariant,
                ),
          ),
        ),
      );
    }

    return FlutterMap(
      mapController: mapController,
      options: const MapOptions(
        initialCenter: LatLng(48.8566, 2.3522),
        initialZoom: 12,
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}@2x?access_token=${AppEnv.mapboxPublicToken}',
          userAgentPackageName: 'com.navia.navia_app',
        ),
        MarkerLayer(markers: markers),
      ],
    );
  }
}
