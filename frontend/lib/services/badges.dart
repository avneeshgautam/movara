import 'workout_log.dart' show formatWorkoutDuration;

/// A single achievement badge, earned from real recorded activity.
class BadgeInfo {
  const BadgeInfo({
    required this.id,
    required this.icon,
    required this.label,
    required this.earned,
    this.detail,
    this.progress = 0,
  });

  final String id;
  final String icon;
  final String label;
  final String? detail; // e.g. "52m", "12 km" — the earned value
  final bool earned;
  final double progress; // 0..1 toward earning, for locked badges

  BadgeInfo copyWith({String? detail, bool? earned, double? progress}) =>
      BadgeInfo(
        id: id,
        icon: icon,
        label: label,
        earned: earned ?? this.earned,
        detail: detail ?? this.detail,
        progress: progress ?? this.progress,
      );
}

/// Everything the badge rules need, pulled from the stores by the caller so the
/// computation stays pure and testable.
class BadgeStats {
  const BadgeStats({
    this.workoutCount = 0,
    this.longestWorkoutSeconds = 0,
    this.workoutStreakDays = 0,
    this.workoutsThisWeek = 0,
    this.totalKm = 0,
    this.longestRunKm = 0,
    this.runCount = 0,
    this.stepsThisWeek = 0,
    this.activityTypes = 0,
  });

  final int workoutCount;
  final int longestWorkoutSeconds;
  final int workoutStreakDays;
  final int workoutsThisWeek;
  final double totalKm;
  final double longestRunKm;
  final int runCount;
  final int stepsThisWeek;
  final int activityTypes; // distinct run/walk/hike types used
}

double _pct(num value, num target) =>
    target <= 0 ? 0 : (value / target).clamp(0.0, 1.0).toDouble();

/// The full badge set, in display order. Every badge is present (earned or
/// locked) so the grid can show progress toward the next ones.
List<BadgeInfo> computeBadges(BadgeStats s) {
  final longest = Duration(seconds: s.longestWorkoutSeconds);
  return [
    // The highlighted "highest workout time" record.
    BadgeInfo(
      id: 'longest_workout',
      icon: '⏱️',
      label: 'Longest Workout',
      earned: s.longestWorkoutSeconds > 0,
      detail: s.longestWorkoutSeconds > 0
          ? formatWorkoutDuration(longest)
          : null,
      progress: _pct(s.longestWorkoutSeconds, 1),
    ),
    BadgeInfo(
      id: 'first_workout',
      icon: '🎯',
      label: 'First Workout',
      earned: s.workoutCount >= 1,
      progress: _pct(s.workoutCount, 1),
    ),
    BadgeInfo(
      id: 'workout_streak',
      icon: '🔥',
      label: 'Streak',
      earned: s.workoutStreakDays >= 3,
      detail: s.workoutStreakDays > 0 ? '${s.workoutStreakDays}d' : null,
      progress: _pct(s.workoutStreakDays, 3),
    ),
    BadgeInfo(
      id: 'consistent',
      icon: '📅',
      label: 'Consistent',
      earned: s.workoutsThisWeek >= 4,
      detail: s.workoutsThisWeek > 0 ? '${s.workoutsThisWeek}/wk' : null,
      progress: _pct(s.workoutsThisWeek, 4),
    ),
    BadgeInfo(
      id: 'iron_will',
      icon: '💪',
      label: '25 Workouts',
      earned: s.workoutCount >= 25,
      detail: s.workoutCount > 0 ? '${s.workoutCount}' : null,
      progress: _pct(s.workoutCount, 25),
    ),
    BadgeInfo(
      id: '5k_runner',
      icon: '🏃',
      label: '5K Runner',
      earned: s.longestRunKm >= 5,
      progress: _pct(s.longestRunKm, 5),
    ),
    BadgeInfo(
      id: 'distance_club',
      icon: '🏅',
      label: '50 km Club',
      earned: s.totalKm >= 50,
      detail: s.totalKm > 0 ? '${s.totalKm.toStringAsFixed(0)} km' : null,
      progress: _pct(s.totalKm, 50),
    ),
    BadgeInfo(
      id: 'step_machine',
      icon: '👟',
      label: 'Step Machine',
      earned: s.stepsThisWeek >= 50000,
      detail: s.stepsThisWeek > 0
          ? '${(s.stepsThisWeek / 1000).toStringAsFixed(0)}k'
          : null,
      progress: _pct(s.stepsThisWeek, 50000),
    ),
    BadgeInfo(
      id: 'all_rounder',
      icon: '🤸',
      label: 'All-Rounder',
      earned: s.activityTypes >= 2,
      progress: _pct(s.activityTypes, 2),
    ),
  ];
}

/// How many of the given badges are earned.
int earnedCount(List<BadgeInfo> badges) =>
    badges.where((b) => b.earned).length;
