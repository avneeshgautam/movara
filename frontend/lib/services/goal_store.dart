import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The user's weekly workout goal: how many sets they aim to log per week.
///
/// Steps aren't available (no pedometer), so the Home goal ring tracks
/// something the app actually measures — sets logged this week — against this
/// editable target.
class GoalStore extends ChangeNotifier {
  static const _key = 'weekly_sets_goal';
  static const defaultGoal = 30;
  static const minGoal = 1;
  static const maxGoal = 500;

  int _weeklySets = defaultGoal;
  bool _loaded = false;

  int get weeklySets => _weeklySets;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _weeklySets = prefs.getInt(_key) ?? defaultGoal;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setWeeklySets(int value) async {
    _weeklySets = value.clamp(minGoal, maxGoal);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, _weeklySets);
  }
}
