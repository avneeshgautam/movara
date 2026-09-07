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
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 22),
              child: Column(
                children: [
                  // 1. Brand at the top.
                  Text(
                    'MOVARA',
                    style: AppTheme.display(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
                    ).copyWith(shadows: _shadows),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 44,
                    height: 3,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // 2. The route in the middle.
                  Expanded(
                    child: run.route.length > 1
                        ? RoutePath(route: run.route, color: accent, strokeWidth: 6)
                        : Center(
                            child: Text(
                              'No route recorded',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 13,
                                  shadows: _shadows),
                            ),
                          ),
                  ),
                  // 3. The details in a row at the bottom.
                  Row(
                    children: [
                      Expanded(
                          child: _stat(
                              'DISTANCE', '${run.distanceKm.toStringAsFixed(2)} km')),
                      _divider(),
                      Expanded(
                          child: _stat(
                              'PACE', '${formatPace(run.paceSecondsPerKm)} /km')),
                      _divider(),
                      Expanded(
                          child: _stat('TIME', formatDuration(run.elapsed))),
                    ],
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
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            shadows: _shadows,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: AppTheme.display(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ).copyWith(shadows: _shadows),
          ),
        ),
      ],
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        color: Colors.white.withValues(alpha: 0.3),
      );

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
