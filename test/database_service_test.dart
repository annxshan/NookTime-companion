import 'package:flutter_test/flutter_test.dart';
import 'package:nooktime/features/daily_routine/domain/models/routine_task.dart';
import 'package:nooktime/features/daily_routine/domain/models/time_log.dart';

void main() {
  group('RoutineTask Data Model Tests', () {
    test('RoutineTask serialization and deserialization roundtrip', () {
      final now = DateTime.now().toUtc();
      final task = RoutineTask(
        id: 'task-123',
        title: 'Morning Yoga',
        category: 'Health',
        startTime: now,
        durationMinutes: 30,
        isCompleted: true,
        googleEventId: 'g-event-456',
        updatedAt: now,
        lastCompletedDate: RoutineTask.todayDateString,
      );

      final map = task.toMap();
      final fromMapTask = RoutineTask.fromMap(map);

      expect(fromMapTask.id, equals(task.id));
      expect(fromMapTask.title, equals(task.title));
      expect(fromMapTask.category, equals(task.category));
      expect(fromMapTask.durationMinutes, equals(task.durationMinutes));
      expect(fromMapTask.isCompleted, equals(true));
      expect(fromMapTask.googleEventId, equals('g-event-456'));
      expect(fromMapTask.lastCompletedDate, equals(RoutineTask.todayDateString));
      expect(fromMapTask.isCompletedToday, isTrue);
    });

    test('RoutineTask copyWith modifies specified fields correctly', () {
      final now = DateTime.now().toUtc();
      final task = RoutineTask(
        id: 'task-1',
        title: 'Read Book',
        category: 'Personal',
        startTime: now,
        durationMinutes: 45,
        isCompleted: false,
        updatedAt: now,
      );

      final updatedTask = task.copyWith(
        isCompleted: true,
        googleEventId: () => 'event-789',
      );

      expect(updatedTask.id, equals(task.id));
      expect(updatedTask.isCompleted, isTrue);
      expect(updatedTask.googleEventId, equals('event-789'));
    });

    test('RoutineTask auto-resets completion state on new day after Sunday in weekly cycle', () {
      final now = DateTime.now().toUtc();
      final taskCompletedOnSunday = RoutineTask(
        id: 'task-weekly-1',
        title: 'Weekly Meal Prep',
        category: 'Health',
        startTime: now,
        durationMinutes: 60,
        isCompleted: true,
        updatedAt: now,
        lastCompletedDate: '2026-08-16', // Past Sunday date
        daysOfWeek: const [1, 2, 3, 4, 5, 6, 7], // Spans all days including Monday
      );

      // Verify task completion automatically resets on a new day (e.g. Monday)
      expect(taskCompletedOnSunday.isCompletedToday, isFalse);
      expect(taskCompletedOnSunday.isScheduledForDay(1), isTrue); // Active on Monday
      expect(taskCompletedOnSunday.isScheduledForDay(7), isTrue); // Active on Sunday
    });
  });

  group('TimeLog Data Model Tests', () {
    test('TimeLog serialization and deserialization roundtrip', () {
      final now = DateTime.now().toUtc();
      final log = TimeLog(
        id: 'log-001',
        taskId: 'task-123',
        timestamp: now,
        durationSpentMinutes: 25,
      );

      final map = log.toMap();
      final fromMapLog = TimeLog.fromMap(map);

      expect(fromMapLog.id, equals(log.id));
      expect(fromMapLog.taskId, equals(log.taskId));
      expect(fromMapLog.durationSpentMinutes, equals(25));
    });
  });
}
