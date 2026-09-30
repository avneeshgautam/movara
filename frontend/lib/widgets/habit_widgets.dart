import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/habit.dart';
import '../theme/app_theme.dart';
import '../theme/movara_colors.dart';

/// Habit colours. User data, like chart series — mid-tones that read on
/// both the light and dark themes.
const habitPalette = <Color>[
  Color(0xFFE07A2E), // orange (brand)
  Color(0xFF2F9E6A), // green
  Color(0xFF3B82C4), // blue
  Color(0xFF8B5CF6), // violet
  Color(0xFFE0457B), // pink
  Color(0xFFD9A21B), // amber
  Color(0xFF14A3A3), // teal
  Color(0xFF6B7280), // slate
];

Color habitColor(Habit h) => habitPalette[h.color % habitPalette.length];

/// Emoji in a circle with a progress ring for today's count.
class HabitRing extends StatelessWidget {
  const HabitRing({super.key, required this.habit, required this.day, this.size = 44});

  final Habit habit;
  final DateTime day;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    final color = habitColor(habit);
    final done = habit.doneOn(day);
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: habit.progressOn(day)),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        builder: (context, p, _) => CustomPaint(
          painter: _RingPainter(p, color, c.border),
          child: Center(
            child: Container(
              width: size - 10,
              height: size - 10,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: done ? color : color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Text(habit.emoji, style: TextStyle(fontSize: size * 0.4)),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.color, this.track);
  final double progress;
  final Color color, track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 3.0;
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    canvas.drawArc(r, 0, math.pi * 2, false,
        Paint()..style = PaintingStyle.stroke..strokeWidth = stroke..color = track);
    if (progress <= 0) return;
    canvas.drawArc(
        r,
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}

/// "🔥 5" chip. Grey when the streak is zero.
class StreakChip extends StatelessWidget {
  const StreakChip({super.key, required this.streak, this.unit = 'day'});

  final int streak;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    final on = streak > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: on ? c.accentSoft : c.surface2,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        on ? '🔥 $streak${unit == 'week' ? 'w' : ''}' : '🔥 0',
        style: AppTheme.display(
          color: on ? c.accent : c.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// One habit on a list: tap to check in (+1), long-press or tap the chevron
/// to open it. The row's background fills as today's progress.
class HabitRow extends StatelessWidget {
  const HabitRow({
    super.key,
    required this.habit,
    required this.day,
    required this.onCheckIn,
    required this.onOpen,
    this.onUndo,
  });

  final Habit habit;
  final DateTime day;
  final VoidCallback onCheckIn;
  final VoidCallback onOpen;
  final VoidCallback? onUndo;

  String _subtitle() {
    final count = habit.countOn(day);
    if (habit.frequency == HabitFrequency.timesPerWeek) {
      return '${habit.doneDaysInWeek(day)}/${habit.timesPerWeek} this week';
    }
    if (habit.targetPerDay > 1) {
      return '$count/${habit.targetPerDay}${habit.unit != null ? ' ${habit.unit}' : ''}';
    }
    return habit.tinyVersion?.isNotEmpty == true
        ? 'Tiny: ${habit.tinyVersion}'
        : habit.scheduleLabel;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    final color = habitColor(habit);
    final done = habit.doneOn(day);
    final progress = habit.progressOn(day);

    return GestureDetector(
      key: ValueKey('habit-row-${habit.id}'),
      onTap: onCheckIn,
      onLongPress: onOpen,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(
                color: done ? color.withValues(alpha: 0.6) : c.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              // Progress fill behind the content.
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: progress),
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  builder: (context, p, _) => FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: p,
                    child: Container(color: color.withValues(alpha: 0.10)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
                child: Row(
                  children: [
                    HabitRing(habit: habit, day: day),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(habit.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.display(
                                color: c.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ).copyWith(
                                  decoration: done && habit.targetPerDay == 1
                                      ? TextDecoration.lineThrough
                                      : null,
                                  decorationColor: c.textMuted)),
                          const SizedBox(height: 2),
                          Text(_subtitle(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  TextStyle(color: c.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    StreakChip(
                        streak: habit.currentStreak(day),
                        unit: habit.streakUnit),
                    if (onUndo != null && habit.countOn(day) > 0)
                      IconButton(
                        key: ValueKey('habit-undo-${habit.id}'),
                        tooltip: 'Undo',
                        visualDensity: VisualDensity.compact,
                        icon: Icon(Icons.remove_circle_outline,
                            size: 20, color: c.textMuted),
                        onPressed: onUndo,
                      )
                    else
                      const SizedBox(width: 6),
                    Icon(done ? Icons.check_circle : Icons.add_circle_outline,
                        color: done ? color : c.textMuted, size: 26),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// This week, Monday to Sunday: filled = done, outlined = planned, faint =
/// not planned. Today has a ring.
class WeekStrip extends StatelessWidget {
  const WeekStrip({super.key, required this.habit, required this.today});

  final Habit habit;
  final DateTime today;

  static const _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    final color = habitColor(habit);
    final monday = Habit.mondayOf(today);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 7; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Builder(builder: (context) {
            final d = monday.add(Duration(days: i));
            final done = habit.doneOn(d);
            final planned = habit.scheduledOn(d);
            final isToday = Habit.dayOf(d) == Habit.dayOf(today);
            return Column(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done
                        ? color
                        : planned
                            ? Colors.transparent
                            : c.surface2,
                    border: Border.all(
                      color: isToday
                          ? c.textPrimary
                          : (done ? color : (planned ? color.withValues(alpha: 0.45) : c.border)),
                      width: isToday ? 2 : 1.2,
                    ),
                  ),
                  child: done
                      ? const Icon(Icons.check, size: 11, color: Colors.white)
                      : null,
                ),
                const SizedBox(height: 3),
                Text(_letters[i],
                    style: TextStyle(
                        fontSize: 9,
                        color: isToday ? c.textPrimary : c.textMuted)),
              ],
            );
          }),
        ],
      ],
    );
  }
}

/// The last [weeks] weeks as a grid (columns = weeks, rows = Mon..Sun).
/// Tap a past day to mark it done / not done.
class HabitHeatmap extends StatelessWidget {
  const HabitHeatmap({
    super.key,
    required this.habit,
    required this.today,
    this.weeks = 12,
    this.onToggleDay,
  });

  final Habit habit;
  final DateTime today;
  final int weeks;
  final ValueChanged<DateTime>? onToggleDay;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    final color = habitColor(habit);
    final firstMonday =
        Habit.mondayOf(today).subtract(Duration(days: 7 * (weeks - 1)));
    final created = Habit.dayOf(habit.createdAt);
    final todayDay = Habit.dayOf(today);

    return LayoutBuilder(builder: (context, box) {
      const gap = 4.0;
      final cell = math.min(
          22.0, (box.maxWidth - 24 - gap * (weeks - 1)) / weeks);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              for (final l in const ['M', '', 'W', '', 'F', '', 'S'])
                SizedBox(
                  height: cell + gap,
                  width: 20,
                  child: Text(l, style: TextStyle(fontSize: 9, color: c.textMuted)),
                ),
            ],
          ),
          for (var w = 0; w < weeks; w++) ...[
            if (w > 0) const SizedBox(width: gap),
            Column(
              children: [
                for (var d = 0; d < 7; d++)
                  Builder(builder: (context) {
                    final day = firstMonday.add(Duration(days: w * 7 + d));
                    final future = day.isAfter(todayDay);
                    final beforeStart = day.isBefore(created);
                    final done = habit.doneOn(day);
                    final partial = !done && habit.countOn(day) > 0;
                    final enabled = onToggleDay != null && !future && !beforeStart;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: gap),
                      child: GestureDetector(
                        onTap: enabled ? () => onToggleDay!(day) : null,
                        child: Container(
                          width: cell,
                          height: cell,
                          decoration: BoxDecoration(
                            color: future || beforeStart
                                ? Colors.transparent
                                : done
                                    ? color
                                    : partial
                                        ? color.withValues(alpha: 0.35)
                                        : (habit.scheduledOn(day)
                                            ? c.surface2
                                            : c.surface2.withValues(alpha: 0.4)),
                            borderRadius: BorderRadius.circular(5),
                            border: day == todayDay
                                ? Border.all(color: c.textPrimary, width: 1.5)
                                : (future || beforeStart
                                    ? Border.all(color: c.border.withValues(alpha: 0.4))
                                    : null),
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ],
        ],
      );
    });
  }
}
