import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../models/run_record.dart';
import '../theme/app_theme.dart';
import 'route_path.dart';

/// A Strava-style share overlay: the route and the run's headline figures on a
/// transparent background (or over a photo you pick), with the MOVARA
/// wordmark. Captured to a transparent PNG so it can sit on top of anything.
class OverlayCard extends StatelessWidget {
  const OverlayCard({
    super.key,
    required this.run,
    required this.boundaryKey,
    this.photo,
    this.accent = const Color(0xFFF97316),
  });

  final RunRecord run;
  final GlobalKey boundaryKey;

  /// Optional background photo; when null the background is transparent.
  final Uint8List? photo;
  final Color accent;

  static const width = 360.0;
  static const height = 560.0;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: boundaryKey,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (photo != null) ...[
              Image.memory(photo!, fit: BoxFit.cover),
              // A soft scrim keeps white text readable over bright photos.
              Container(color: Colors.black.withValues(alpha: 0.28)),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              child: Column(
                children: [
                  _stat('DISTANCE', '${run.distanceKm.toStringAsFixed(2)} km'),
                  const SizedBox(height: 18),
                  _stat('PACE', '${formatPace(run.paceSecondsPerKm)} /km'),
                  const SizedBox(height: 18),
                  _stat('TIME', formatDuration(run.elapsed)),
                  const SizedBox(height: 10),
                  Expanded(
                    child: run.route.length > 1
                        ? RoutePath(route: run.route, color: accent, strokeWidth: 6)
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'MOVARA',
                    style: AppTheme.display(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                    ).copyWith(shadows: _shadows),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            shadows: _shadows,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          textAlign: TextAlign.center,
          style: AppTheme.display(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w800,
          ).copyWith(shadows: _shadows),
        ),
      ],
    );
  }

  static const _shadows = [
    Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 1)),
  ];
}

/// Rasterises the overlay behind [boundaryKey] to a transparent PNG.
Future<Uint8List?> captureOverlay(GlobalKey boundaryKey,
    {double pixelRatio = 3}) async {
  final object = boundaryKey.currentContext?.findRenderObject();
  if (object is! RenderRepaintBoundary) return null;
  final image = await object.toImage(pixelRatio: pixelRatio);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data?.buffer.asUint8List();
}
