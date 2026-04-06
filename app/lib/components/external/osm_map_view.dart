import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class OsmMapView extends StatelessWidget {
  const OsmMapView({
    super.key,
    required this.center,
    this.zoom = 13,
    this.markers = const <Marker>[],
    this.interactiveFlags = InteractiveFlag.all,
  });

  final LatLng center;
  final double zoom;
  final List<Marker> markers;
  final int interactiveFlags;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        interactionOptions: InteractionOptions(flags: interactiveFlags),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.navia.navia_app',
        ),
        if (markers.isNotEmpty) MarkerLayer(markers: markers),
      ],
    );
  }
}

