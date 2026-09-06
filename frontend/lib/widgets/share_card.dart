import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';

import '../models/run_record.dart';
import '../theme/app_theme.dart';
import '../theme/movara_colors.dart';
import 'route_map.dart';

/// The image produced by "Share": the route with distance, time and pace
/// across the bottom.
///
/// Rendered as ordinary Flutter widgets so [RepaintBoundary] can rasterise it.
class ShareCard extends StatelessWidget {
  const ShareCard({super.key, required this.run, required this.boundaryKey});

  final RunRecord run;
  final GlobalKey boundaryKey;

  static const width = 360.0;
  static const height = 480.0;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;

    return RepaintBoundary(
      key: boundaryKey,
      child: Container(
        width: width,
        height: height,
        color: c.bg,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RouteMap(route: run.route, interactive: false),
                  // Keeps the wordmark legible over pale map tiles.
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            c.bg.withValues(alpha: 0.85),
                            c.bg.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'MOVARA',
                            style: AppTheme.display(
                              color: c.accent,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.4,
                            ),
                          ),
                          Text(
                            DateFormat('d MMM yyyy').format(run.startedAt),
                            style: TextStyle(color: c.textPrimary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(top: BorderSide(color: c.border)),
              ),
              child: Row(
                children: [
                  _stat(context, 'DISTANCE', run.distanceKm.toStringAsFixed(2), 'km'),
                  _divider(context),
                  _stat(context, 'TIME', formatDuration(run.elapsed), ''),
                  _divider(context),
                  _stat(context, 'PACE', formatPace(run.paceSecondsPerKm), '/km'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(BuildContext context) => Container(
        width: 1,
        height: 34,
        color: context.movara.border,
      );

  Widget _stat(BuildContext context, String label, String value, String unit) {
    final c = context.movara;
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(color: c.textMuted, fontSize: 9, letterSpacing: 1.4),
          ),
          const SizedBox(height: 5),
          RichText(
            text: TextSpan(
              text: value,
              style: AppTheme.display(
                color: c.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
              children: [
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                      color: c.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Rasterises the card behind [boundaryKey] to PNG bytes.
Future<Uint8List?> captureShareCard(GlobalKey boundaryKey,
    {double pixelRatio = 3}) async {
  final object = boundaryKey.currentContext?.findRenderObject();
  if (object is! RenderRepaintBoundary) return null;

  final image = await object.toImage(pixelRatio: pixelRatio);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data?.buffer.asUint8List();
}
