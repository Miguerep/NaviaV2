import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../api/navia_api.dart';
import '../../../providers/explore_provider.dart';
import '../../../providers/trip_provider.dart';
import '../../../theme/navia_theme.dart';
import 'widgets/explore_widgets.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final p = ExploreProvider(context.read<NaviaApi>());
        final trip = context.read<TripProvider>();
        final lat = trip.startLat;
        final lng = trip.startLng;
        if (lat != null && lng != null) {
          p.setUserLocation(GeoPoint(lat: lat, lng: lng));
        }
        return p;
      },
      child: const _ExploreScreenUI(),
    );
  }
}

class _ExploreScreenUI extends StatefulWidget {
  const _ExploreScreenUI();

  @override
  State<_ExploreScreenUI> createState() => _ExploreScreenUIState();
}

class _ExploreScreenUIState extends State<_ExploreScreenUI> {
  final _searchController = TextEditingController();
  final _mapController = MapController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) async {
    final provider = context.read<ExploreProvider>();
    await provider.search(query);
    
    if (provider.results.isNotEmpty) {
      final firstWithCenter = provider.results.firstWhere(
        (r) => r.center != null,
        orElse: () => provider.results.first,
      );
      final c = firstWithCenter.center;
      if (c != null) {
        _mapController.move(LatLng(c.lat, c.lng), 14);
      }
    }
  }

  Future<void> _openPlace(PlaceResult p) async {
    if (p.center == null) return;
    
    // Fetch route silently in the background
    final provider = context.read<ExploreProvider>();
    final route = await provider.getRouteToPlace(p);

    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: NaviaThemeTokens.surfaceContainerLowest,
      builder: (context) => _PlaceBottomSheet(place: p, route: route),
    );
  }

  @override
  Widget build(BuildContext context) {
    final destination = context.watch<TripProvider>().destination;
    final provider = context.watch<ExploreProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.mic),
          ),
        ],
      ),
      body: Padding(
        padding: NaviaThemeTokens.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search bars, restaurants...',
                suffixIcon: Icon(Icons.mic),
              ),
              onSubmitted: _onSearch,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: NaviaThemeTokens.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Map (next step)',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Destination: ${destination ?? '-'}',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: NaviaThemeTokens.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: ExploreMap(
                            mapController: _mapController,
                            places: provider.results,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (provider.loading) const LinearProgressIndicator(),
                      if (provider.error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          provider.error!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: NaviaThemeTokens.error,
                              ),
                        ),
                      ],
                      if (provider.results.isEmpty && !provider.loading)
                        Text(
                          'Search to see places.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: NaviaThemeTokens.onSurfaceVariant,
                              ),
                        )
                      else if (!provider.loading)
                        Column(
                          children: [
                            for (final p in provider.results.take(5)) ...[
                              const SizedBox(height: 10),
                              PlaceListTile(
                                place: p,
                                onTap: p.center == null
                                    ? () {}
                                    : () {
                                        _mapController.move(
                                          LatLng(p.center!.lat, p.center!.lng),
                                          15,
                                        );
                                        _openPlace(p);
                                      },
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _PlaceBottomSheet extends StatelessWidget {
  const _PlaceBottomSheet({required this.place, required this.route});
  final PlaceResult place;
  final RouteResult? route;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            place.name.isEmpty ? place.placeName : place.name,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            place.placeName,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: NaviaThemeTokens.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          if (route != null) ...[
            _metricRow(
              context,
              icon: Icons.near_me,
              title: '${_fmtKm(route!.distanceMeters)} away',
              subtitle: 'Walking',
            ),
            const SizedBox(height: 10),
            _metricRow(
              context,
              icon: Icons.timer,
              title: '${_fmtMin(route!.durationSeconds)} min',
              subtitle: 'Estimated',
            ),
          ] else ...[
             Text(
              'No route found.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: NaviaThemeTokens.error,
                  ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _metricRow(BuildContext context, {required IconData icon, required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: NaviaThemeTokens.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: NaviaThemeTokens.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: NaviaThemeTokens.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtKm(double? meters) {
    if (meters == null) return '-';
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _fmtMin(double? seconds) {
    if (seconds == null) return '-';
    return (seconds / 60).round().toString();
  }
}
