import 'dart:math' as math;

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
    // Use the app-level ExploreProvider (hoisted to main.dart).
    // Seed user location from the trip GPS if available.
    final trip = context.read<TripProvider>();
    final explore = context.read<ExploreProvider>();
    final lat = trip.startLat;
    final lng = trip.startLng;
    if (lat != null && lng != null) {
      explore.setUserLocation(GeoPoint(lat: lat, lng: lng));
    }
    return const _ExploreScreenUI();
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

    // Listen for active route changes and move the map accordingly.
    final explore = context.read<ExploreProvider>();
    explore.addListener(_onExploreChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    context.read<ExploreProvider>().removeListener(_onExploreChanged);
    super.dispose();
  }

  /// React to active route being set from the itinerary screen.
  void _onExploreChanged() {
    final explore = context.read<ExploreProvider>();
    if (explore.hasActiveRoute) {
      final route = explore.activeRoute!;
      final polyline = route.polyline;
      if (polyline.length > 1) {
        // Fit to the route polyline bounds
        final center = _polylineCenter(polyline);
        final zoom = _zoomForPolyline(polyline);
        _mapController.move(center, zoom);
      } else if (explore.activeDestination != null) {
        _mapController.move(explore.activeDestination!, 15);
      }
    }
  }

  LatLng _polylineCenter(List<LatLng> polyline) {
    final lats = polyline.map((p) => p.latitude);
    final lngs = polyline.map((p) => p.longitude);
    return LatLng(
      (lats.reduce(math.min) + lats.reduce(math.max)) / 2,
      (lngs.reduce(math.min) + lngs.reduce(math.max)) / 2,
    );
  }

  double _zoomForPolyline(List<LatLng> points) {
    if (points.length < 2) return 14;
    final lats = points.map((p) => p.latitude);
    final lngs = points.map((p) => p.longitude);
    final latSpan = lats.reduce(math.max) - lats.reduce(math.min);
    final lngSpan = lngs.reduce(math.max) - lngs.reduce(math.min);
    final span = math.max(latSpan, lngSpan);
    if (span < 0.005) return 15;
    if (span < 0.02) return 14;
    if (span < 0.05) return 13;
    if (span < 0.1) return 12;
    return 11;
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
        actions: [
          // Show a "clear route" button when a walk route is active
          if (provider.hasActiveRoute)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Clear route',
              onPressed: () => provider.clearActiveRoute(),
            ),
          const Padding(
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

            // ── Active route info banner ──────────────────────────
            if (provider.hasActiveRoute) ...[
              const SizedBox(height: 12),
              _ActiveRouteBanner(provider: provider),
            ],

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
                        activeRoute: provider,
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

// ── Active route banner ───────────────────────────────────────────────────────

class _ActiveRouteBanner extends StatelessWidget {
  const _ActiveRouteBanner({required this.provider});
  final ExploreProvider provider;

  @override
  Widget build(BuildContext context) {
    final route = provider.activeRoute;
    final name = provider.activeDestinationName ?? 'destination';

    final dist = route?.distanceMeters;
    final dur = route?.durationSeconds;
    final distStr = dist == null
        ? '—'
        : dist < 1000
            ? '${dist.round()} m'
            : '${(dist / 1000).toStringAsFixed(1)} km';
    final durStr = dur == null ? '—' : '${(dur / 60).round()} min';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: NaviaThemeTokens.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: NaviaThemeTokens.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.directions_walk, color: NaviaThemeTokens.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Walking to $name',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: NaviaThemeTokens.onSurface,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$distStr · $durStr',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: NaviaThemeTokens.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: NaviaThemeTokens.onSurfaceVariant,
            onPressed: () => provider.clearActiveRoute(),
          ),
        ],
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
