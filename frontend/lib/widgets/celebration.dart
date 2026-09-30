import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/movara_colors.dart';

/// Shows a confetti burst with a message card over the whole screen, then
/// removes itself. [big] is the "all habits done" version: more confetti and
/// a longer hold.
void showCelebration(
  BuildContext context, {
  required String title,
  required String subtitle,
  String emoji = '🎉',
  bool big = false,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  HapticFeedback.heavyImpact();
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Celebration(
      title: title,
      subtitle: subtitle,
      emoji: emoji,
      big: big,
      onDone: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _Celebration extends StatefulWidget {
  const _Celebration({
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.big,
    required this.onDone,
  });

  final String title;
  final String subtitle;
  final String emoji;
  final bool big;
  final VoidCallback onDone;

  @override
  State<_Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<_Celebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.big ? 3200 : 2400),
  )..forward().whenComplete(widget.onDone);

  late final List<_Piece> _pieces = _Piece.burst(widget.big ? 140 : 70);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          // Card pops in, holds, fades out over the last 20%.
          final cardIn = Curves.elasticOut.transform((t / 0.25).clamp(0, 1));
          final fade = t < 0.8 ? 1.0 : (1 - (t - 0.8) / 0.2).clamp(0.0, 1.0);
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _ConfettiPainter(_pieces, t, [
                    c.accent,
                    c.green,
                    c.blue,
                    const Color(0xFFFFC53D),
                    const Color(0xFFFF6B9A),
                  ]),
                ),
              ),
              Center(
                child: Opacity(
                  opacity: fade,
                  child: Transform.scale(
                    scale: 0.6 + 0.4 * cardIn,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 36),
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: c.accent.withValues(alpha: 0.5)),
                          boxShadow: [
                            BoxShadow(
                                color: c.accentGlow,
                                blurRadius: 30,
                                offset: const Offset(0, 10)),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(widget.emoji,
                                style: TextStyle(fontSize: widget.big ? 52 : 42)),
                            const SizedBox(height: 8),
                            Text(widget.title,
                                textAlign: TextAlign.center,
                                style: AppTheme.display(
                                    color: c.textPrimary,
                                    fontSize: widget.big ? 22 : 19,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text(widget.subtitle,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: c.textSecondary, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One confetti piece: where it starts, how it flies, and its spin.
class _Piece {
  _Piece(this.x, this.vx, this.vy, this.spin, this.size, this.color, this.round);

  final double x, vx, vy, spin, size;
  final int color;
  final bool round;

  static List<_Piece> burst(int n) {
    final r = math.Random();
    return List.generate(
      n,
      (_) => _Piece(
        0.2 + r.nextDouble() * 0.6, // start across the middle band
        (r.nextDouble() - 0.5) * 0.9, // sideways drift
        -0.9 - r.nextDouble() * 0.9, // initial upward kick
        (r.nextDouble() - 0.5) * 18,
        5 + r.nextDouble() * 6,
        r.nextInt(5),
        r.nextBool(),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t, this.colors);

  final List<_Piece> pieces;
  final double t;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    const gravity = 2.4;
    final fade = t < 0.75 ? 1.0 : (1 - (t - 0.75) / 0.25).clamp(0.0, 1.0);
    for (final p in pieces) {
      // Launched from ~40% down the screen, arcs up then falls.
      final x = (p.x + p.vx * t) * size.width;
      final y = (0.42 + p.vy * t + gravity * t * t / 2) * size.height;
      if (y > size.height + 20) continue;
      final paint = Paint()
        ..color = colors[p.color].withValues(alpha: fade);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * t);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5),
            paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
