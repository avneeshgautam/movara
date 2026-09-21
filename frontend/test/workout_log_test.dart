import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movara_app/services/badges.dart';
import 'package:movara_app/services/workout_log.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('WorkoutLog', () {
    test('ignores workouts shorter than 20 seconds', () async {
      final log = WorkoutLog();
      await log.load();
      await log.add(duration: const Duration(seconds: 10));
      expect(log.totalCount, 0);
      expect(log.countToday(), 0);
    });

    test('records a finished workout and derives the daily count', () async {
      final log = WorkoutLog();
      await log.load();
      await log.add(duration: const Duration(minutes: 30));
      await log.add(duration: const Duration(minutes: 45));
      expect(log.totalCount, 2);
      expect(log.countToday(), 2);
      expect(log.timeToday(), const Duration(minutes: 75));
    });

    test('longestSeconds is the single best session', () async {
      final log = WorkoutLog();
      await log.load();
      await log.add(duration: const Duration(minutes: 20));
      await log.add(duration: const Duration(minutes: 52));
      await log.add(duration: const Duration(minutes: 31));
      expect(log.longestSeconds, const Duration(minutes: 52).inSeconds);
    });

    test('streak counts consecutive workout days back from today', () async {
      final log = WorkoutLog();
      await log.load();
      final now = DateTime.now();
      await log.add(
          duration: const Duration(minutes: 30), startedAt: now);
      await log.add(
          duration: const Duration(minutes: 30),
          startedAt: now.subtract(const Duration(days: 1)));
      // Gap on day -2, activity on day -3 => streak stops at 2.
      await log.add(
          duration: const Duration(minutes: 30),
          startedAt: now.subtract(const Duration(days: 3)));
      expect(log.streakDays, 2);
    });

    test('persists across reloads', () async {
      final log = WorkoutLog();
      await log.load();
      await log.add(duration: const Duration(minutes: 40));

      final reopened = WorkoutLog();
      await reopened.load();
      expect(reopened.totalCount, 1);
      expect(reopened.longestSeconds, const Duration(minutes: 40).inSeconds);
    });
  });

  group('computeBadges', () {
    test('longest-workout badge is earned and formatted', () {
      final badges = computeBadges(const BadgeStats(
        workoutCount: 3,
        longestWorkoutSeconds: 52 * 60,
      ));
      final longest = badges.firstWhere((b) => b.id == 'longest_workout');
      expect(longest.earned, isTrue);
      expect(longest.detail, '52m');
    });

    test('nothing earned on empty stats except progress toward locked', () {
      final badges = computeBadges(const BadgeStats());
      expect(earnedCount(badges), 0);
      expect(badges.every((b) => b.progress >= 0), isTrue);
    });

    test('streak badge needs 3 days', () {
      expect(
          computeBadges(const BadgeStats(workoutStreakDays: 2))
              .firstWhere((b) => b.id == 'workout_streak')
              .earned,
          isFalse);
      expect(
          computeBadges(const BadgeStats(workoutStreakDays: 3))
              .firstWhere((b) => b.id == 'workout_streak')
              .earned,
          isTrue);
    });
  });
}
