import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nooktime/features/gamification/services/streak_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StreakService Unit Tests', () {
    late SharedPreferences prefs;
    late StreakService streakService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      streakService = StreakService(prefs);
    });

    test('Returns false when tasks are incomplete or total is 0', () async {
      final res0 = await streakService.checkAndIncrementStreak(
        totalTasks: 0,
        completedTasks: 0,
      );
      expect(res0, isFalse);

      final resIncomplete = await streakService.checkAndIncrementStreak(
        totalTasks: 3,
        completedTasks: 2,
      );
      expect(resIncomplete, isFalse);
      expect(await streakService.getCurrentStreak(), equals(0));
    });

    test('Increments streak on first daily completion', () async {
      final earned = await streakService.checkAndIncrementStreak(
        totalTasks: 3,
        completedTasks: 3,
      );

      expect(earned, isTrue);
      expect(await streakService.getCurrentStreak(), equals(1));
      expect(await streakService.getBestStreak(), equals(1));
      expect(await streakService.isTodayCompleted(), isTrue);
    });

    test('Returns false if today was already completed', () async {
      await streakService.checkAndIncrementStreak(
        totalTasks: 2,
        completedTasks: 2,
      );

      final secondCall = await streakService.checkAndIncrementStreak(
        totalTasks: 2,
        completedTasks: 2,
      );

      expect(secondCall, isFalse);
      expect(await streakService.getCurrentStreak(), equals(1));
    });

    test('Resets streak if last completion was older than yesterday', () async {
      final oldDate = '2026-08-01';
      await prefs.setString(StreakService.keyLastCompletedDate, oldDate);
      await prefs.setInt(StreakService.keyCurrentStreak, 5);
      await prefs.setInt(StreakService.keyBestStreak, 5);

      final current = await streakService.getCurrentStreak();
      expect(current, equals(0));

      final earned = await streakService.checkAndIncrementStreak(
        totalTasks: 1,
        completedTasks: 1,
      );

      expect(earned, isTrue);
      expect(await streakService.getCurrentStreak(), equals(1));
      expect(await streakService.getBestStreak(), equals(5));
    });
  });
}
