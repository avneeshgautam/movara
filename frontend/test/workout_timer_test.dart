import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movara_app/services/workout_timer.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('starts at zero and stopped', () async {
    final t = WorkoutTimer();
    await t.load();
    expect(t.isRunning, isFalse);
    expect(t.elapsed, Duration.zero);
    t.dispose();
  });

  test('counts up from the wall clock while running', () async {
    final t = WorkoutTimer();
    await t.load();
    await t.start();
    expect(t.isRunning, isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(t.elapsed.inMilliseconds, greaterThanOrEqualTo(1000));
    t.dispose();
  });

  test('pause banks the time and stops the clock', () async {
    final t = WorkoutTimer();
    await t.load();
    await t.start();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await t.pause();

    final atPause = t.elapsed;
    expect(t.isRunning, isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(t.elapsed, atPause, reason: 'paused time must not grow');
    t.dispose();
  });

  test('resumes and keeps the earlier banked time', () async {
    final t = WorkoutTimer();
    await t.load();
    await t.start();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await t.pause();
    final banked = t.elapsed;
    await t.start();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(t.elapsed, greaterThan(banked));
    t.dispose();
  });

  test('reset clears it', () async {
    final t = WorkoutTimer();
    await t.load();
    await t.start();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await t.reset();
    expect(t.elapsed, Duration.zero);
    expect(t.isRunning, isFalse);
    t.dispose();
  });

  test('a running timer keeps its time across a reload (same day)', () async {
    final first = WorkoutTimer();
    await first.load();
    await first.start();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    first.dispose();

    final second = WorkoutTimer();
    await second.load();
    expect(second.isRunning, isTrue);
    expect(second.elapsed.inMilliseconds, greaterThanOrEqualTo(250));
    second.dispose();
  });

  test('a stale day resets to zero', () async {
    SharedPreferences.setMockInitialValues({
      'workout_timer_day': '2000-1-1',
      'workout_timer_banked_ms': 999999,
    });
    final t = WorkoutTimer();
    await t.load();
    expect(t.elapsed, Duration.zero);
    t.dispose();
  });
}
