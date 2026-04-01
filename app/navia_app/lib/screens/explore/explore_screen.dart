import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../api/navia_api.dart';
import '../../theme/navia_theme.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({
    super.key,
    required this.destination,
    required this.tripDates,
  });

  final String? destination;
  final DateTimeRange? tripDates;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _controller = TextEditingController();
  final _api = NaviaApi(baseUrl: 'http://127.0.0.1:8787');
  final _mapController = MapController();

  bool _loading = false;
  String? _error;
  List<PlaceResult> _results = const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const _mapboxToken = String.fromEnvironment('MAPBOX_PUBLIC_TOKEN');

  Future<void> _search(String raw) async {
    final q = raw.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await _api.searchPlaces(query: q);
      setState(() => _results = results);
      final firstWithCenter = results.firstWhere(
        (r) => r.center != null,
        orElse: () => results.isEmpty ? PlaceResult(id: '', name: '', placeName: '', center: null, categories: const []) : results.first,
      );
      final c = firstWithCenter.center;
      if (c != null) {
        _mapController.move(LatLng(c.lat, c.lng), 14);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openPlace(PlaceResult p) async {
    if (p.center == null) return;
    final from = GeoPoint(lat: 48.8566, lng: 2.3522);
    RouteResult? route;
    String? routeError;

    try {
      route = await _api.getRouteWalking(from: from, to: p.center!);
    } catch (e) {
      routeError = e.toString();
    }

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: NaviaThemeTokens.surfaceContainerLowest,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.name.isEmpty ? p.placeName : p.name,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                p.placeName,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: NaviaThemeTokens.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              if (route != null) ...[
                _metricRow(
                  context,
                  icon: Icons.near_me,
                  title: '${_fmtKm(route.distanceMeters)} away',
                  subtitle: 'Walking',
                ),
                const SizedBox(height: 10),
                _metricRow(
                  context,
                  icon: Icons.timer,
                  title: '${_fmtMin(route.durationSeconds)} min',
                  subtitle: 'Estimated',
                ),
              ] else if (routeError != null) ...[
                Text(
                  routeError,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: NaviaThemeTokens.error,
                      ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Get Directions'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _metricRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
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

  @override
  Widget build(BuildContext context) {
    final destination = widget.destination;
    final canShowMap = _mapboxToken.trim().isNotEmpty;
    final markers = _results
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
              controller: _controller,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search bars, restaurants...',
                suffixIcon: Icon(Icons.mic),
              ),
              onSubmitted: _search,
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
                          child: canShowMap
                              ? FlutterMap(
                                  mapController: _mapController,
                                  options: MapOptions(
                                    initialCenter: const LatLng(48.8566, 2.3522),
                                    initialZoom: 12,
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate:
                                          'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}@2x?access_token=$_mapboxToken',
                                      userAgentPackageName: 'com.navia.navia_app',
                                    ),
                                    MarkerLayer(markers: markers),
                                  ],
                                )
                              : Container(
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
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_loading) const LinearProgressIndicator(),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: NaviaThemeTokens.error,
                              ),
                        ),
                      ],
                      _results.isEmpty
                          ? Text(
                              'Search to see places.\n(If you see MAPBOX_NOT_CONFIGURED, set MAPBOX_TOKEN in the API env.)',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: NaviaThemeTokens.onSurfaceVariant,
                                  ),
                            )
                          : Column(
                              children: [
                                for (final p in _results.take(5)) ...[
                                  const SizedBox(height: 10),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(18),
                                    onTap: p.center == null
                                        ? null
                                        : () {
                                            _mapController.move(
                                              LatLng(p.center!.lat, p.center!.lng),
                                              15,
                                            );
                                            _openPlace(p);
                                          },
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color:
                                            NaviaThemeTokens.surfaceContainerLowest,
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p.name.isEmpty
                                                ? p.placeName
                                                : p.name,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w900,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            p.placeName,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: NaviaThemeTokens
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
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

