import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/movara_colors.dart';

/// Up to three concentric progress rings, each 0..1, with a soft fill
/// animation. Outer + inner are always drawn; a third (innermost) ring is
/// drawn when [thirdColor] is given. Used on Home for sets / distance / steps.
class DualGoalRing extends StatelessWidget {
  const DualGoalRing({
    super.key,
    required this.outer,
    required this.inner,
    required this.outerColor,
    required this.innerColor,
    required this.centerTop,
    required this.centerBottom,
    this.third = 0,
    this.thirdColor,
    this.size = 130,
    this.animate = true,
  });

  final double outer;
  final double inner;
  final double third;
  final Color outerColor;
  final Color innerColor;
  final Color? thirdColor;
  final String centerTop;
  final String centerBottom;
  final double size;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    final hasThird = thirdColor != null;
    final stroke = hasThird ? 7.5 : 9.0;

    Widget painterAt(double t) => CustomPaint(
          size: Size.square(size),
          painter: _RingPainter(
            outer: (outer * t).clamp(0, 1),
            inner: (inner * t).clamp(0, 1),
            third: hasThird ? (third * t).clamp(0, 1) : null,
            track: c.border,
            outerColor: outerColor,
            innerColor: innerColor,
            thirdColor: thirdColor,
            stroke: stroke,
          ),
        );

    final ring = animate
        ? TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) => painterAt(t),
          )
        : painterAt(1);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ring,
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

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.outer,
    required this.inner,
    required this.third,
    required this.track,
    required this.outerColor,
    required this.innerColor,
    required this.thirdColor,
    required this.stroke,
  });

  final double outer;
  final double inner;
  final double? third;
  final Color track;
  final Color outerColor;
  final Color innerColor;
  final Color? thirdColor;
  final double stroke;

  static const _gap = 4.0;

  void _ring(Canvas canvas, Offset center, double radius, double pct, Color color) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
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
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outerRadius = (size.width - stroke) / 2;
    final innerRadius = outerRadius - stroke - _gap;
    _ring(canvas, center, outerRadius, outer, outerColor);
    _ring(canvas, center, innerRadius, inner, innerColor);
    if (third != null && thirdColor != null) {
      final thirdRadius = innerRadius - stroke - _gap;
      _ring(canvas, center, thirdRadius, third!, thirdColor!);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.outer != outer ||
      old.inner != inner ||
      old.third != third ||
      old.outerColor != outerColor ||
      old.innerColor != innerColor ||
      old.thirdColor != thirdColor ||
      old.stroke != stroke ||
      old.track != track;
}
