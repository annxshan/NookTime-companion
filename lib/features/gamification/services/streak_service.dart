import 'package:shared_preferences/shared_preferences.dart';

/// Service responsible for managing Duolingo-style daily habit completion streaks.
class StreakService {
  static const String keyCurrentStreak = 'current_streak';
  static const String keyBestStreak = 'best_streak';
  static const String keyLastCompletedDate = 'last_completed_date';

  final SharedPreferences _prefs;

  StreakService(this._prefs);

  static Future<StreakService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return StreakService(prefs);
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Evaluates and increments current streak if all tasks for today are completed.
  /// Returns `true` if today's completion streak was freshly earned.
  Future<bool> checkAndIncrementStreak({
    required int totalTasks,
    required int completedTasks,
  }) async {
    if (totalTasks == 0 || completedTasks < totalTasks) {
      return false;
    }

    final now = DateTime.now();
    final todayStr = _formatDate(now);
    final yesterdayStr = _formatDate(now.subtract(const Duration(days: 1)));

    final lastCompleted = _prefs.getString(keyLastCompletedDate);

    if (lastCompleted == todayStr) {
      return false; // Streak already recorded today
    }

    int currentStreak = _prefs.getInt(keyCurrentStreak) ?? 0;
    int bestStreak = _prefs.getInt(keyBestStreak) ?? 0;

    if (currentStreak > bestStreak) {
      bestStreak = currentStreak;
    }

    if (lastCompleted == yesterdayStr) {
      currentStreak += 1;
    } else {
      currentStreak = 1;
    }

    if (currentStreak > bestStreak) {
      bestStreak = currentStreak;
    }

    await _prefs.setInt(keyCurrentStreak, currentStreak);
    await _prefs.setInt(keyBestStreak, bestStreak);
    await _prefs.setString(keyLastCompletedDate, todayStr);

    return true;
  }

  /// Returns current active streak count, automatically resetting to 0 if a day was missed.
  Future<int> getCurrentStreak() async {
    final lastCompleted = _prefs.getString(keyLastCompletedDate);
    if (lastCompleted == null || lastCompleted.isEmpty) {
      return 0;
    }

    final now = DateTime.now();
    final todayStr = _formatDate(now);
    final yesterdayStr = _formatDate(now.subtract(const Duration(days: 1)));

    if (lastCompleted != todayStr && lastCompleted != yesterdayStr) {
      // User missed a day; reset current streak in storage to 0
      await _prefs.setInt(keyCurrentStreak, 0);
      return 0;
    }

    return _prefs.getInt(keyCurrentStreak) ?? 0;
  }

  /// Returns all-time best streak count.
  Future<int> getBestStreak() async {
    return _prefs.getInt(keyBestStreak) ?? 0;
  }

  /// Returns whether today's total tasks were already marked completed.
  Future<bool> isTodayCompleted() async {
    final lastCompleted = _prefs.getString(keyLastCompletedDate);
    final todayStr = _formatDate(DateTime.now());
    return lastCompleted == todayStr;
  }
}
