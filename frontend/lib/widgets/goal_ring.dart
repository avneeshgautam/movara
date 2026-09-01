import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/movara_colors.dart';

/// The circular progress ring from the design: a full track with an accent
/// arc drawn over it, starting at 12 o'clock and sweeping clockwise.
class GoalRing extends StatelessWidget {
  const GoalRing({super.key, required this.percent, this.size = 148});

  /// 0-100.
  final int percent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _RingPainter(
              percent: percent.clamp(0, 100) / 100,
              track: c.border,
              accent: c.accent,
              glow: c.accentGlow,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$percent%',
                style: AppTheme.display(
                  color: c.accent,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'of Goal',
                style: TextStyle(color: c.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.percent,
    required this.track,
    required this.accent,
    required this.glow,
  });

  final double percent;
  final Color track;
  final Color accent;
  final Color glow;

  static const _stroke = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.width - _stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..color = track,
    );

    if (percent <= 0) return;

    // The CSS version rotates the SVG -90deg so the arc begins at the top.
    const startAngle = -math.pi / 2;
    final sweep = percent * 2 * math.pi;

    // Approximates the design's drop-shadow glow around the arc.
    canvas.drawArc(
      rect,
      startAngle,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round
        ..color = glow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    canvas.drawArc(
      rect,
      startAngle,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round
        ..color = accent,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.percent != percent ||
      old.track != track ||
      old.accent != accent ||
      old.glow != glow;
}
