import 'package:flutter_test/flutter_test.dart';
import 'package:nooktime/features/daily_routine/domain/models/routine_task.dart';
import 'package:nooktime/features/daily_routine/domain/models/time_log.dart';
import 'package:nooktime/features/time_analytics/services/analytics_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AnalyticsEngine Isolate Computation Tests', () {
    test('Calculates focus hours, completion rate, and trends accurately', () async {
      final now = DateTime.now().toUtc();
      final startDate = DateTime(now.year, now.month, now.day);
      final endDate = startDate.add(const Duration(days: 2));

      final tasks = [
        RoutineTask(
          id: 'task-1',
          title: 'Coding',
          category: 'Work',
          startTime: startDate,
          durationMinutes: 60,
          isCompleted: true,
          lastCompletedDate: RoutineTask.todayDateString,
          updatedAt: now,
        ),
        RoutineTask(
          id: 'task-2',
          title: 'Running',
          category: 'Health',
          startTime: startDate,
          durationMinutes: 30,
          isCompleted: false,
          updatedAt: now,
        ),
      ];

      final logs = [
        TimeLog(
          id: 'log-1',
          taskId: 'task-1',
          timestamp: startDate,
          durationSpentMinutes: 120,
        ),
        TimeLog(
          id: 'log-2',
          taskId: 'task-2',
          timestamp: startDate.add(const Duration(days: 1)),
          durationSpentMinutes: 60,
        ),
      ];

      final result = await AnalyticsEngine.processInIsolate(
        tasks: tasks,
        logs: logs,
        startDate: startDate,
        endDate: endDate,
      );

      expect(result.totalFocusHours, equals(3.0)); // 180 minutes = 3.0 hours
      expect(result.completionRate, equals(0.5)); // 1 of 2 completed
      expect(result.completedTasksCount, equals(1));
      expect(result.doneTasksCount, equals(1));
      expect(result.pendingTasksCount, equals(1));
      expect(result.totalTasksCount, equals(2));
      expect(result.mostProductiveDay, isNotEmpty);
      expect(result.categoryDistribution['Work'], equals(2.0));
      expect(result.categoryDistribution['Health'], equals(1.0));
      expect(result.dailyTrends.length, equals(3));
      expect(result.dailyTrends[0].hoursSpent, equals(2.0));
      expect(result.dailyTrends[1].hoursSpent, equals(1.0));
    });
  });
}

