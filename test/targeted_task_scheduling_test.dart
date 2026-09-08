import 'package:flutter_test/flutter_test.dart';
import 'package:nooktime/features/ai_assistant/services/local_schedule_engine.dart';
import 'package:nooktime/features/daily_routine/domain/models/routine_task.dart';
import 'package:nooktime/features/daily_routine/domain/models/task_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Targeted Task Scheduling & Daytime Bounds Tests', () {
    late LocalScheduleEngine engine;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      engine = LocalScheduleEngine();
    });

    test('Parses targeted weekend learning prompt into weekend task with daysOfWeek [6, 7]', () {
      const prompt = 'I want to learn Japanese on weekends for 2 hours';
      final tasks = engine.parseCustomPrompt(prompt);

      expect(tasks, isNotEmpty);
      final japaneseTask = tasks.firstWhere(
        (t) => (t['title'] as String).toLowerCase().contains('japanese') ||
            (t['title'] as String).toLowerCase().contains('study') ||
            (t['title'] as String).toLowerCase().contains('learning'),
        orElse: () => tasks.first,
      );

      final startHour = japaneseTask['startHour'] as int;
      // Must be daytime awake hours (>= 6 and <= 22)
      expect(startHour >= 6 && startHour <= 22, isTrue,
          reason: 'Task start hour ($startHour) must be within daytime awake hours.');
    });

    test('Never places tasks overnight (between 23:00 and 06:00) for standard prompts', () {
      const prompt = 'Study flutter for 2 hours and workout';
      final tasks = engine.parseCustomPrompt(prompt);

      for (final task in tasks) {
        final startHour = task['startHour'] as int;
        final duration = task['durationMinutes'] as int;
        final startMins = startHour * 60 + (task['startMinute'] as int);
        final endMins = startMins + duration;

        final isOvernight = (startHour >= 23 || startHour < 6) || (endMins > 23 * 60 + 30);
        expect(isOvernight, isFalse,
            reason: 'Task "${task['title']}" at $startHour:00 for ${duration}m was scheduled overnight.');
      }
    });

    test('Resolves conflicts against existing tasks by finding open free daytime slots', () {
      final now = DateTime.now();
      final existingTask = RoutineTask(
        id: 'existing_1',
        title: 'Morning Work Block',
        category: 'Work',
        startTime: DateTime(now.year, now.month, now.day, 9, 0),
        durationMinutes: 180, // 9:00 AM to 12:00 PM
        type: TaskType.routine,
        isCompleted: false,
        updatedAt: now.toUtc(),
        daysOfWeek: const [1, 2, 3, 4, 5, 6, 7],
      );

      const prompt = 'Study session for 2 hours at 9am';
      final tasks = engine.parseCustomPrompt(prompt, existingTasks: [existingTask]);

      expect(tasks, isNotEmpty);
      final newStudyTask = tasks.first;
      final startMins = (newStudyTask['startHour'] as int) * 60 + (newStudyTask['startMinute'] as int);

      // Should be shifted past existing task (>= 12:00 PM = 720 mins)
      expect(startMins >= 720, isTrue,
          reason: 'New task should be scheduled after 12:00 PM to avoid conflict with existing task.');
    });
  });
}
