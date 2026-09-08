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

  static const defaultSets = 30;
  static const defaultKm = 15.0;
  static const minSets = 1;
  static const maxSets = 500;
  static const minKm = 0.5;
  static const maxKm = 200.0;

  GoalPeriod _period = GoalPeriod.weekly;
  int _sets = defaultSets;
  double _km = defaultKm;
  bool _loaded = false;

  GoalPeriod get period => _period;
  int get setsGoal => _sets;
  double get kmGoal => _km;
  bool get isLoaded => _loaded;

  String get periodLabel => _period == GoalPeriod.daily ? 'Daily' : 'Weekly';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _period = (prefs.getString(_kPeriod) == 'daily')
        ? GoalPeriod.daily
        : GoalPeriod.weekly;
    _sets = prefs.getInt(_kSets) ?? defaultSets;
    _km = prefs.getDouble(_kKm) ?? defaultKm;
    _loaded = true;
    notifyListeners();
  }

  Future<void> save({
    required GoalPeriod period,
    required int sets,
    required double km,
  }) async {
    _period = period;
    _sets = sets.clamp(minSets, maxSets);
    _km = km.clamp(minKm, maxKm);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPeriod, period == GoalPeriod.daily ? 'daily' : 'weekly');
    await prefs.setInt(_kSets, _sets);
    await prefs.setDouble(_kKm, _km);
  }
}
