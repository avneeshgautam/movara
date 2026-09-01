import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/movara_colors.dart';

const _weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/// Rounded panel used by most dashboard cards.
class MovaraCard extends StatelessWidget {
  const MovaraCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }
}

/// "TODAY'S OVERVIEW" style heading, with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: AppTheme.display(
              color: c.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.6,
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                action!,
                style: TextStyle(
                  color: c.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Streak card: flame, day count, and a 7-day bar strip.
class StreakCard extends StatelessWidget {
  const StreakCard({super.key, required this.days});

  /// How many of the last 7 days are "hit". 0-7.
  final int days;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;

    return MovaraCard(
      color: c.surface2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                'Streak',
                style: AppTheme.display(
                  color: c.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$days',
            style: AppTheme.display(
              color: c.accent,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            days == 1 ? 'day in a row' : 'days in a row',
            style: TextStyle(color: c.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(_weekdayLabels.length, (i) {
              final hit = i < days;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == 6 ? 0 : 4),
                  child: Column(
                    children: [
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: hit ? c.accent : c.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _weekdayLabels[i],
                        style: TextStyle(
                          fontSize: 9,
                          color: hit ? c.accent : c.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Small labelled stat tile (Calories / Distance / Active).
class MiniStat extends StatelessWidget {
  const MiniStat({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.surface3,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: c.textMuted,
              fontSize: 10,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.display(
                    color: c.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 3),
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Text(
                  unit,
                  style: TextStyle(color: c.textSecondary, fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One "Congrats! ..." achievement row.
class AchievementCard extends StatelessWidget {
  const AchievementCard({
    super.key,
    required this.emoji,
    required this.title,
    required this.description,
    required this.date,
    required this.tint,
  });

  final String emoji;
  final String title;
  final String description;
  final String date;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;

    return MovaraCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Congrats! $title',
                  style: AppTheme.display(
                    color: c.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(color: c.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(date, style: TextStyle(color: c.textMuted, fontSize: 10)),
        ],
      ),
    );
  }
}

/// Seven-bar weekly chart. [values] are 0-1 fractions, Monday first.
class WeeklyChart extends StatelessWidget {
  const WeeklyChart({super.key, required this.values, required this.todayIndex});

  final List<double> values;
  final int todayIndex;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;

    return MovaraCard(
      child: SizedBox(
        height: 74,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(7, (i) {
            final isToday = i == todayIndex;
            final fraction = (i < values.length ? values[i] : 0.0).clamp(0.0, 1.0);

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == 6 ? 0 : 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: c.surface3,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        // Align (not Column) so the fill receives bounded
                        // height constraints -- inside a Column the vertical
                        // constraint is unbounded and the fraction collapses
                        // to zero, leaving every bar empty.
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            widthFactor: 1,
                            heightFactor: fraction == 0 ? 0.0 : fraction,
                            child: Container(
                              decoration: BoxDecoration(
                                color: isToday ? c.accent : c.surface2,
                                border: Border.all(
                                  color: isToday ? c.accent : c.border,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _weekdayLabels[i],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: isToday ? c.accent : c.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
