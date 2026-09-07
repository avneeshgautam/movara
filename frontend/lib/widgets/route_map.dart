import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/run_record.dart';
import '../theme/movara_colors.dart';

/// Draws a run's path on OpenStreetMap tiles.
///
/// flutter_map renders tiles as ordinary Flutter widgets rather than an
/// embedded native/HTML view, which is what lets the share card capture the
/// map as an image.
class RouteMap extends StatelessWidget {
  const RouteMap({
    super.key,
    required this.route,
    this.live,
    this.interactive = true,
    this.controller,
    this.followLive = false,
    this.lineColor,
  });

  final List<RunPoint> route;

  /// Current position, shown as a pulsing head marker while recording.
  final RunPoint? live;
  final bool interactive;
  final MapController? controller;
  final bool followLive;

  /// Overrides the polyline colour (the shared cards use blue); defaults to
  /// the app accent for the live/history map.
  final Color? lineColor;

  static const _fallbackCentre = LatLng(20.5937, 78.9629); // India

  /// Test hook. Widget tests have no network, so tile requests throw and fail
  /// the test; setting this swaps in an offline provider.
  @visibleForTesting
  static TileProvider? debugTileProvider;

  LatLng get _centre {
    if (live != null) return LatLng(live!.lat, live!.lng);
    if (route.isNotEmpty) {
      final mid = route[route.length ~/ 2];
      return LatLng(mid.lat, mid.lng);
    }
    return _fallbackCentre;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    final points = route.map((p) => LatLng(p.lat, p.lng)).toList();

    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: _centre,
        initialZoom: route.isEmpty && live == null ? 4 : 17,
        interactionOptions: InteractionOptions(
          flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
        ),
        // Fit a finished route into view once the map is laid out.
        initialCameraFit: points.length > 1
            ? CameraFit.coordinates(
                coordinates: points,
                padding: const EdgeInsets.all(22),
                maxZoom: 18,
              )
            : null,
      ),
      children: [
        TileLayer(
          tileProvider: debugTileProvider,
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          // OpenStreetMap asks that apps identify themselves.
          userAgentPackageName: 'com.avneesh.movara',
          maxZoom: 19,
        ),
        if (points.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(points: points, strokeWidth: 5, color: lineColor ?? c.accent),
            ],
          ),
        MarkerLayer(
          markers: [
            if (points.isNotEmpty)
              Marker(
                point: points.first,
                width: 16,
                height: 16,
                child: _Dot(colour: c.green),
              ),
            if (live != null)
              Marker(
                point: LatLng(live!.lat, live!.lng),
                width: 20,
                height: 20,
                child: _Dot(colour: c.accent, size: 20),
              )
            else if (points.length > 1)
              Marker(
                point: points.last,
                width: 16,
                height: 16,
                child: const _Dot(colour: Color(0xFFEF4444)),
              ),
          ],
        ),
        // OSM's licence requires visible attribution.
        const RichAttributionWidget(
          attributions: [
            TextSourceAttribution('OpenStreetMap contributors'),
          ],
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.colour, this.size = 16});

  final Color colour;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colour,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [BoxShadow(color: colour.withValues(alpha: 0.5), blurRadius: 8)],
      ),
    );
  }
}
