import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../api/navia_api.dart';
import '../../providers/explore_provider.dart';
import '../../providers/trip_provider.dart';
import '../../theme/navia_theme.dart';
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

  /// Resolved initial map centre. Starts as null (loading), then set to
  /// the trip's GPS coords (fast) or geocoded city coords (async fallback).
  LatLng? _initialCenter;

  @override
  void initState() {
    super.initState();
    _resolveInitialCenter();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Determine the best initial map centre:
  ///   1. Use trip startLat/startLng when available (set during onboarding GPS step).
  ///   2. Geocode the destination city name as a fallback.
  ///   3. Hard-code a safe world-centre fallback.
  Future<void> _resolveInitialCenter() async {
    final trip = context.read<TripProvider>();

    // Option 1 — GPS coordinates saved from onboarding
    if (trip.startLat != null && trip.startLng != null) {
      if (mounted) {
        setState(() {
          _initialCenter = LatLng(trip.startLat!, trip.startLng!);
        });
      }
      return;
    }

    // Option 2 — geocode the destination city name
    final destination = trip.destination;
    if (destination != null && destination.trim().isNotEmpty) {
      try {
        final api = context.read<NaviaApi>();
        final results = await api.searchPlaces(
          query: destination.trim(),
          limit: 1,
        );
        final center = results.isEmpty ? null : results.first.center;
        if (center != null && mounted) {
          final coords = LatLng(center.lat, center.lng);
          setState(() => _initialCenter = coords);
          // Also move the controller in case the map is already rendered
          _mapController.move(coords, 13);
          return;
        }
      } catch (_) {
        // Geocoding failed — fall through to default
      }
    }

    // Option 3 — world centre (user hasn't set a destination yet)
    if (mounted) {
      setState(() => _initialCenter = const LatLng(20.0, 0.0));
    }
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
    final trip = context.watch<TripProvider>();
    final provider = context.watch<ExploreProvider>();

    // While geocoding resolves, show a shimmer/placeholder map centred on world
    final center = _initialCenter ?? const LatLng(20.0, 0.0);
    final zoom = _initialCenter == null ? 2.0 : 13.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(trip.destination ?? 'Explore'),
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
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: trip.destination != null
                    ? 'Search in ${trip.destination}...'
                    : 'Search bars, restaurants...',
                suffixIcon: const Icon(Icons.mic),
              ),
              onSubmitted: _onSearch,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    // ── Full-bleed map ──────────────────────────────────
                    Positioned.fill(
                      child: ExploreMap(
                        mapController: _mapController,
                        places: provider.results,
                        initialCenter: center,
                        initialZoom: zoom,
                      ),
                    ),

                    // ── Loading indicator while geocoding ───────────────
                    if (_initialCenter == null)
                      const Positioned(
                        top: 12,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(),
                      ),

                    // ── Search results list overlay (bottom) ────────────
                    if (provider.results.isNotEmpty || provider.loading || provider.error != null)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _ResultsPanel(
                          provider: provider,
                          mapController: _mapController,
                          onTap: _openPlace,
                        ),
                      ),
                  ],
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

// ── Results panel displayed as a floating card over the map ────────────────────

class _ResultsPanel extends StatelessWidget {
  const _ResultsPanel({
    required this.provider,
    required this.mapController,
    required this.onTap,
  });

  final ExploreProvider provider;
  final MapController mapController;
  final Future<void> Function(PlaceResult) onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NaviaThemeTokens.surfaceContainerLowest.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: NaviaThemeTokens.onSurface.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (provider.loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(),
              ),
            if (provider.error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  provider.error!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: NaviaThemeTokens.error,
                      ),
                ),
              ),
            if (!provider.loading && provider.results.isNotEmpty)
              Flexible(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shrinkWrap: true,
                  itemCount: provider.results.take(5).length,
                  separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, index) {
                    final p = provider.results[index];
                    return ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: NaviaThemeTokens.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.place, color: NaviaThemeTokens.primary, size: 20),
                      ),
                      title: Text(
                        p.name.isEmpty ? p.placeName : p.name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        p.placeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: NaviaThemeTokens.onSurfaceVariant,
                            ),
                      ),
                      onTap: p.center == null
                          ? null
                          : () {
                              mapController.move(
                                LatLng(p.center!.lat, p.center!.lng),
                                15,
                              );
                              onTap(p);
                            },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Place bottom sheet (unchanged) ─────────────────────────────────────────────

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

  Widget _metricRow(BuildContext context,
      {required IconData icon, required String title, required String subtitle}) {
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
