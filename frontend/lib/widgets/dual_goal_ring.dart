import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/movara_colors.dart';

/// Two concentric progress rings — outer and inner — each 0..1. Used on Home
/// to show workout sets (outer) and running distance (inner) against goals.
class DualGoalRing extends StatelessWidget {
  const DualGoalRing({
    super.key,
    required this.outer,
    required this.inner,
    required this.outerColor,
    required this.innerColor,
    required this.centerTop,
    required this.centerBottom,
    this.size = 130,
  });

  final double outer;
  final double inner;
  final Color outerColor;
  final Color innerColor;
  final String centerTop;
  final String centerBottom;
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
            painter: _DualRingPainter(
              outer: outer.clamp(0, 1),
              inner: inner.clamp(0, 1),
              track: c.border,
              outerColor: outerColor,
              innerColor: innerColor,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(centerTop.toUpperCase(),
                  style: AppTheme.display(
                      color: c.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      height: 1)),
              const SizedBox(height: 2),
              Text(centerBottom.toUpperCase(),
                  style: TextStyle(
                      color: c.textMuted, fontSize: 8, letterSpacing: 1)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DualRingPainter extends CustomPainter {
  _DualRingPainter({
    required this.outer,
    required this.inner,
    required this.track,
    required this.outerColor,
    required this.innerColor,
  });

  final double outer;
  final double inner;
  final Color track;
  final Color outerColor;
  final Color innerColor;

  static const _stroke = 9.0;
  static const _gap = 5.0;

  void _ring(Canvas canvas, Offset center, double radius, double pct, Color color) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..color = track,
    );
    if (pct <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      pct * 2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outerRadius = (size.width - _stroke) / 2;
    final innerRadius = outerRadius - _stroke - _gap;
    _ring(canvas, center, outerRadius, outer, outerColor);
    _ring(canvas, center, innerRadius, inner, innerColor);
  }

  @override
  bool shouldRepaint(_DualRingPainter old) =>
      old.outer != outer ||
      old.inner != inner ||
      old.outerColor != outerColor ||
      old.innerColor != innerColor ||
      old.track != track;
}
