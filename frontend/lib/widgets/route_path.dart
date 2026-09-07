import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/run_record.dart';

/// Draws a run's route as a bare polyline — no map tiles — scaled to fit its
/// box. Used on the transparent share overlay, where map tiles (which are
/// opaque) would defeat the transparency.
class RoutePath extends StatelessWidget {
  const RoutePath({
    super.key,
    required this.route,
    required this.color,
    this.strokeWidth = 5,
  });

  final List<RunPoint> route;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RoutePainter(route, color, strokeWidth),
      size: Size.infinite,
    );
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter(this.route, this.color, this.strokeWidth);

  final List<RunPoint> route;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (route.length < 2) return;

    var minLat = route.first.lat, maxLat = route.first.lat;
    var minLng = route.first.lng, maxLng = route.first.lng;
    for (final p in route) {
      if (p.lat < minLat) minLat = p.lat;
      if (p.lat > maxLat) maxLat = p.lat;
      if (p.lng < minLng) minLng = p.lng;
      if (p.lng > maxLng) maxLng = p.lng;
    }

    // Longitude degrees cover less ground than latitude ones as you leave the
    // equator; correcting keeps the shape from looking stretched sideways.
    final midLatRad = ((minLat + maxLat) / 2) * math.pi / 180;
    final lngScale = math.cos(midLatRad).abs().clamp(0.01, 1.0);

    final spanX = ((maxLng - minLng) * lngScale).abs();
    final spanY = (maxLat - minLat).abs();
    if (spanX == 0 && spanY == 0) return;

    const pad = 16.0;
    final availW = size.width - pad * 2;
    final availH = size.height - pad * 2;
    final scale = spanX / spanY > availW / availH
        ? (spanX == 0 ? availH / spanY : availW / spanX)
        : (spanY == 0 ? availW / spanX : availH / spanY);

    final drawnW = spanX * scale;
    final drawnH = spanY * scale;
    final offsetX = pad + (availW - drawnW) / 2;
    final offsetY = pad + (availH - drawnH) / 2;

    Offset toPixel(RunPoint p) {
      final x = offsetX + ((p.lng - minLng) * lngScale) * scale;
      // Latitude grows northward, but screen y grows downward — invert.
      final y = offsetY + (maxLat - p.lat) * scale;
      return Offset(x, y);
    }

    final path = Path()..moveTo(toPixel(route.first).dx, toPixel(route.first).dy);
    for (final p in route.skip(1)) {
      final o = toPixel(p);
      path.lineTo(o.dx, o.dy);
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _RoutePainter old) =>
      old.route != route || old.color != color || old.strokeWidth != strokeWidth;
}
