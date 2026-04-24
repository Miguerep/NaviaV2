import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../theme/navia_theme.dart';

class OsmMapView extends StatefulWidget {
  const OsmMapView({
    super.key,
    required this.center,
    this.mapController,
    this.zoom = 13,
    this.markers = const <Marker>[],
    this.polyline = const <LatLng>[],
    this.interactiveFlags = InteractiveFlag.all,
  });

  final LatLng center;
  final MapController? mapController;
  final double zoom;
  final List<Marker> markers;

  /// If non-empty, draws a coloured walking route polyline over the map.
  final List<LatLng> polyline;
  final int interactiveFlags;

  @override
  State<OsmMapView> createState() => _OsmMapViewState();
}

class _OsmMapViewState extends State<OsmMapView> {
  late final MapController _internalController;
  MapController get _controller => widget.mapController ?? _internalController;

  @override
  void initState() {
    super.initState();
    _internalController = MapController();
  }

  @override
  void didUpdateWidget(covariant OsmMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.center != widget.center) {
      _controller.move(widget.center, widget.zoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: widget.center,
        initialZoom: widget.zoom,
        interactionOptions: InteractionOptions(flags: widget.interactiveFlags),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.navia.navia_app',
        ),
        if (widget.polyline.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: widget.polyline,
                color: NaviaThemeTokens.primary,
                strokeWidth: 5,
                borderColor: NaviaThemeTokens.primary.withValues(alpha: 0.25),
                borderStrokeWidth: 10,
              ),
            ],
          ),
        if (widget.markers.isNotEmpty) MarkerLayer(markers: widget.markers),
      ],
    );
  }
}
