import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nooktime/core/services/database_service.dart';
import 'package:nooktime/features/daily_routine/domain/models/routine_task.dart';
import 'package:nooktime/features/daily_routine/domain/models/time_log.dart';
import 'package:nooktime/features/time_analytics/presentation/analytics_controller.dart';
import 'package:nooktime/features/time_analytics/presentation/analytics_screen.dart';

class TestDatabaseService extends DatabaseService {
  TestDatabaseService() : super.forTest();

  @override
  Future<List<RoutineTask>> getAllTasks() async => [];

  @override
  Future<List<TimeLog>> getTimeLogsByDateRange(
          DateTime startDate, DateTime endDate) async =>
      [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AnalyticsScreen renders correctly in UI widget tree',
      (WidgetTester tester) async {
    final controller =
        AnalyticsController(databaseService: TestDatabaseService());

    await tester.pumpWidget(MaterialApp(
      home: AnalyticsScreen(controller: controller),
    ));

    expect(find.text('Time Analytics'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('This Week'), findsOneWidget);
    expect(find.text('This Month'), findsOneWidget);
  });

  group('RoutineTask midnight auto-reset logic', () {
    final now = DateTime.now().toUtc();

    test('isCompletedToday is true when lastCompletedDate == today', () {
      final today = RoutineTask.todayDateString;
      final task = RoutineTask(
        id: 'task-1',
        title: 'Morning Run',
        category: 'Health',
        startTime: now,
        durationMinutes: 30,
        isCompleted: true,
        updatedAt: now,
        lastCompletedDate: today,
      );

      expect(task.isCompletedToday, isTrue);
    });

    test('isCompletedToday is false when lastCompletedDate is yesterday', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayStr =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

      final task = RoutineTask(
        id: 'task-2',
        title: 'Evening Yoga',
        category: 'Health',
        startTime: now,
        durationMinutes: 30,
        isCompleted: true, // was completed yesterday
        updatedAt: now,
        lastCompletedDate: yesterdayStr,
      );

      // Even though isCompleted == true in DB, today it should appear uncompleted
      expect(task.isCompletedToday, isFalse,
          reason: 'Routine completed yesterday should reset at midnight');
    });

    test('isCompletedToday is false when lastCompletedDate is null', () {
      final task = RoutineTask(
        id: 'task-3',
        title: 'Reading',
        category: 'Personal',
        startTime: now,
        durationMinutes: 20,
        isCompleted: false,
        updatedAt: now,
      );

      expect(task.isCompletedToday, isFalse);
    });

    test('copyWith preserves lastCompletedDate when not overridden', () {
      final today = RoutineTask.todayDateString;
      final task = RoutineTask(
        id: 'task-4',
        title: 'Meditation',
        category: 'Personal',
        startTime: now,
        durationMinutes: 15,
        isCompleted: true,
        updatedAt: now,
        lastCompletedDate: today,
      );

      final copied = task.copyWith(title: 'Deep Meditation');
      expect(copied.lastCompletedDate, equals(today));
      expect(copied.title, equals('Deep Meditation'));
    });

    test('copyWith can clear lastCompletedDate via nullable callback', () {
      final task = RoutineTask(
        id: 'task-5',
        title: 'Journaling',
        category: 'Personal',
        startTime: now,
        durationMinutes: 15,
        isCompleted: false,
        updatedAt: now,
        lastCompletedDate: '2024-01-01',
      );

      final cleared = task.copyWith(lastCompletedDate: () => null);
      expect(cleared.lastCompletedDate, isNull);
    });

    test('RoutineTask serialisation roundtrip includes lastCompletedDate', () {
      final today = RoutineTask.todayDateString;
      final task = RoutineTask(
        id: 'task-6',
        title: 'Morning Yoga',
        category: 'Health',
        startTime: now,
        durationMinutes: 30,
        isCompleted: true,
        googleEventId: 'g-event-abc',
        updatedAt: now,
        lastCompletedDate: today,
      );

      final map = task.toMap();
      expect(map['last_completed_date'], equals(today));

      final fromMap = RoutineTask.fromMap(map);
      expect(fromMap.lastCompletedDate, equals(today));
      expect(fromMap.isCompletedToday, isTrue);
    });
  });
}
