import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../api/navia_api.dart';
import '../../../components/external/osm_map_view.dart';
import '../../../providers/trip_provider.dart';
import '../../../theme/navia_theme.dart';

/// Full-screen bottom sheet that:
///   1. Geocodes [stop] title to get its coordinates (via places search).
///   2. Fetches a walking route from the trip start point to that place.
///   3. Draws the route on an interactive OSM map.
class RouteMapSheet extends StatefulWidget {
  const RouteMapSheet({super.key, required this.stop});

  final Stop stop;

  /// Convenience wrapper — push the sheet from any context.
  static Future<void> show(BuildContext context, Stop stop) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: NaviaThemeTokens.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => RouteMapSheet(stop: stop),
    );
  }

  @override
  State<RouteMapSheet> createState() => _RouteMapSheetState();
}

class _RouteMapSheetState extends State<RouteMapSheet> {
  _RouteState _state = _RouteState.loading;
  String? _error;
  GeoPoint? _destination;
  RouteResult? _route;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final trip = context.read<TripProvider>();
    final api = context.read<NaviaApi>();

    final originLat = trip.startLat;
    final originLng = trip.startLng;

    // Build a search query: "stop title, destination city"
    final query = [widget.stop.title, trip.destination]
        .whereType<String>()
        .where((s) => s.trim().isNotEmpty)
        .join(', ');

    try {
      // Step 1 — geocode the stop name
      final results = await api.searchPlaces(
        query: query,
        nearLatLng: (originLat != null && originLng != null)
            ? '$originLat,$originLng'
            : null,
        limit: 1,
      );

      final place = results.isEmpty ? null : results.first;
      final dest = place?.center;

      if (dest == null) {
        if (!mounted) return;
        setState(() {
          _state = _RouteState.error;
          _error = 'Could not locate "${widget.stop.title}" on the map.';
        });
        return;
      }

      _destination = dest;

      // Step 2 — fetch walking route (only possible if we have a start point)
      if (originLat != null && originLng != null) {
        final route = await api.getRouteWalking(
          from: GeoPoint(lat: originLat, lng: originLng),
          to: dest,
        );
        if (!mounted) return;
        setState(() {
          _route = route;
          _state = _RouteState.ready;
        });
      } else {
        if (!mounted) return;
        setState(() => _state = _RouteState.ready);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _RouteState.error;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = context.read<TripProvider>();
    final height = MediaQuery.sizeOf(context).height * 0.75;

    return SizedBox(
      height: height,
      child: Column(
        children: [
          // ── Handle + header ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.stop.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                if ((widget.stop.subtitle ?? '').trim().isNotEmpty)
                  Text(
                    widget.stop.subtitle!,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: NaviaThemeTokens.onSurfaceVariant,
                        ),
                  ),
                if (_route != null) ...[
                  const SizedBox(height: 8),
                  _MetricRow(route: _route!),
                ],
              ],
            ),
          ),
          // ── Map / loading / error ─────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _buildMapBody(trip),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapBody(TripProvider trip) {
    if (_state == _RouteState.loading) {
      return ColoredBox(
        color: NaviaThemeTokens.surfaceContainerLow,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_state == _RouteState.error) {
      return ColoredBox(
        color: NaviaThemeTokens.surfaceContainerLow,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: NaviaThemeTokens.error,
                  ),
            ),
          ),
        ),
      );
    }

    // Determine map centre: midpoint of polyline or fallback
    final polyline = _route?.polyline ?? const [];
    final center = _mapCenter(
      polyline: polyline,
      origin: (trip.startLat != null && trip.startLng != null)
          ? LatLng(trip.startLat!, trip.startLng!)
          : null,
      dest: _destination != null
          ? LatLng(_destination!.lat, _destination!.lng)
          : null,
    );

    final markers = <Marker>[
      if (_destination != null)
        Marker(
          point: LatLng(_destination!.lat, _destination!.lng),
          width: 40,
          height: 40,
          child: _PinIcon(color: NaviaThemeTokens.primary),
        ),
      if (trip.startLat != null && trip.startLng != null)
        Marker(
          point: LatLng(trip.startLat!, trip.startLng!),
          width: 36,
          height: 36,
          child: _PinIcon(
            color: NaviaThemeTokens.secondary,
            icon: Icons.my_location,
          ),
        ),
    ];

    return OsmMapView(
      center: center,
      zoom: _zoomForPolyline(polyline),
      markers: markers,
      polyline: polyline,
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

enum _RouteState { loading, ready, error }

LatLng _mapCenter({
  required List<LatLng> polyline,
  LatLng? origin,
  LatLng? dest,
}) {
  if (polyline.isNotEmpty) {
    // Midpoint of the polyline bounding box
    final lats = polyline.map((p) => p.latitude);
    final lngs = polyline.map((p) => p.longitude);
    return LatLng(
      (lats.reduce(math.min) + lats.reduce(math.max)) / 2,
      (lngs.reduce(math.min) + lngs.reduce(math.max)) / 2,
    );
  }
  if (dest != null && origin != null) {
    return LatLng(
      (dest.latitude + origin.latitude) / 2,
      (dest.longitude + origin.longitude) / 2,
    );
  }
  return dest ?? origin ?? const LatLng(48.8566, 2.3522);
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

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.route});
  final RouteResult route;

  @override
  Widget build(BuildContext context) {
    final dist = route.distanceMeters;
    final dur = route.durationSeconds;
    final distStr = dist == null
        ? '—'
        : dist < 1000
            ? '${dist.round()} m'
            : '${(dist / 1000).toStringAsFixed(1)} km';
    final durStr =
        dur == null ? '—' : '${(dur / 60).round()} min';

    return Wrap(
      spacing: 12,
      children: [
        _Chip(icon: Icons.near_me, label: distStr),
        _Chip(icon: Icons.timer, label: durStr),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: NaviaThemeTokens.primaryDim.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: NaviaThemeTokens.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: NaviaThemeTokens.primary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _PinIcon extends StatelessWidget {
  const _PinIcon({required this.color, this.icon = Icons.place});
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }
}
