import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movara_app/services/workout_timer.dart';

/// The gym timer drives the Lock Screen Live Activity through a platform
/// channel; record what it sends.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('movara/live_activity');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('start shows a distance-free Workout card; pause ends it', () async {
    final timer = WorkoutTimer();
    await timer.load();
    await timer.start();

    final start = calls.singleWhere((c) => c.method == 'start');
    expect(start.arguments['label'], 'Workout');
    expect(start.arguments['showsDistance'], isFalse);

    await timer.pause();
    expect(calls.last.method, 'end');
    timer.dispose();
  });

  test('resuming backdates the card by the time already banked', () async {
    final timer = WorkoutTimer();
    await timer.load();
    await timer.start();
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await timer.pause();
    calls.clear();

    await timer.start();
    final resume = calls.singleWhere((c) => c.method == 'start');
    expect(resume.arguments['elapsedSeconds'] as num, greaterThanOrEqualTo(1));
    timer.dispose();
  });

  test('reset ends the card; resetting an idle timer sends nothing', () async {
    final timer = WorkoutTimer();
    await timer.load();
    await timer.reset();
    expect(calls.where((c) => c.method == 'end'), isEmpty);

    await timer.start();
    await timer.reset();
    expect(calls.last.method, 'end');
    timer.dispose();
  });
}
