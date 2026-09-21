import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum GoalPeriod { daily, weekly }

/// The user's activity goals: workout sets and running distance, over a chosen
/// period. Shown on Home as two concentric rings. No pedometer, so these track
/// what the app actually measures.
class GoalStore extends ChangeNotifier {
  static const _kPeriod = 'goal_period';
  static const _kSets = 'goal_sets';
  static const _kKm = 'goal_km';
  static const _kSteps = 'goal_steps';

  // Stored values are the WEEKLY targets; daily targets are derived (÷7).
  static const defaultSets = 30;
  static const defaultKm = 15.0;
  static const defaultSteps = 42000; // ~6k/day
  static const minSets = 1;
  static const maxSets = 500;
  static const minKm = 0.5;
  static const maxKm = 200.0;
  static const minSteps = 1000;
  static const maxSteps = 500000;

  GoalPeriod _period = GoalPeriod.weekly;
  int _sets = defaultSets;
  double _km = defaultKm;
  int _steps = defaultSteps;
  bool _loaded = false;

  GoalPeriod get period => _period;
  bool get isLoaded => _loaded;

  // Weekly targets.
  int get setsGoal => _sets;
  double get kmGoal => _km;
  int get stepsGoal => _steps;

  // Daily targets, derived from the weekly ones.
  int get dailySetsGoal => (_sets / 7).ceil().clamp(1, maxSets);
  double get dailyKmGoal => _km / 7;
  int get dailyStepsGoal => (_steps / 7).round().clamp(1, maxSteps);

  String get periodLabel => _period == GoalPeriod.daily ? 'Daily' : 'Weekly';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _period = (prefs.getString(_kPeriod) == 'daily')
        ? GoalPeriod.daily
        : GoalPeriod.weekly;
    _sets = prefs.getInt(_kSets) ?? defaultSets;
    _km = prefs.getDouble(_kKm) ?? defaultKm;
    _steps = prefs.getInt(_kSteps) ?? defaultSteps;
    _loaded = true;
    notifyListeners();
  }

  Future<void> save({
    required GoalPeriod period,
    required int sets,
    required double km,
    int? steps,
  }) async {
    _period = period;
    _sets = sets.clamp(minSets, maxSets);
    _km = km.clamp(minKm, maxKm);
    if (steps != null) _steps = steps.clamp(minSteps, maxSteps);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPeriod, period == GoalPeriod.daily ? 'daily' : 'weekly');
    await prefs.setInt(_kSets, _sets);
    await prefs.setDouble(_kKm, _km);
    await prefs.setInt(_kSteps, _steps);
  }
}
