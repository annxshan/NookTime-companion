import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nooktime/core/services/database_service.dart';
import 'package:nooktime/core/services/notification_service.dart';
import 'package:nooktime/features/ai_assistant/presentation/ai_planner_bottom_sheet.dart';
import 'package:nooktime/features/calendar_sync/services/auth_service.dart';
import 'package:nooktime/features/calendar_sync/services/google_calendar_service.dart';
import 'package:nooktime/features/daily_routine/data/routine_repository.dart';
import 'package:nooktime/features/daily_routine/domain/models/routine_task.dart';
import 'package:nooktime/features/daily_routine/domain/models/time_log.dart';

class TestDatabaseService extends DatabaseService {
  TestDatabaseService() : super.forTest();

  @override
  Future<List<RoutineTask>> getAllTasks() async => [];

  @override
  Future<List<RoutineTask>> getTodayRoutines() async => [];

  @override
  Future<List<TimeLog>> getTimeLogsByDateRange(
          DateTime startDate, DateTime endDate) async =>
      [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AiPlannerBottomSheet renders correctly in UI tree',
      (WidgetTester tester) async {
    final db = TestDatabaseService();
    final auth = AuthService();
    final notif = NotificationService();
    final calendar = GoogleCalendarService(authService: auth);

    final repo = RoutineRepository(
      databaseService: db,
      notificationService: notif,
      googleCalendarService: calendar,
      authService: auth,
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AiPlannerBottomSheet(
          routineRepository: repo,
        ),
      ),
    ));

    expect(find.text('AI Routine Planner'), findsOneWidget);
    expect(find.text('Preset Goals'), findsOneWidget);
    expect(find.text('Generate Schedule with AI'), findsOneWidget);
  });

  testWidgets('Selecting a preset goal defaults all proposed tasks to selected',
      (WidgetTester tester) async {
    final db = TestDatabaseService();
    final auth = AuthService();
    final notif = NotificationService();
    final calendar = GoogleCalendarService(authService: auth);

    final repo = RoutineRepository(
      databaseService: db,
      notificationService: notif,
      googleCalendarService: calendar,
      authService: auth,
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AiPlannerBottomSheet(
          routineRepository: repo,
        ),
      ),
    ));

    // Tap on Exam Prep Mode preset chip
    final presetChip = find.text('🎯 Exam Prep Mode');
    expect(presetChip, findsOneWidget);
    await tester.tap(presetChip);
    await tester.pumpAndSettle();

    // Verify proposed schedule appears with default selected tasks
    expect(find.textContaining('Proposed Schedule'), findsOneWidget);
    final deselectAllFinder = find.text('Deselect All');
    expect(deselectAllFinder, findsOneWidget);

    // Ensure visible and tap Deselect All
    await tester.ensureVisible(deselectAllFinder);
    await tester.tap(deselectAllFinder, warnIfMissed: false);
    await tester.pumpAndSettle();

    final selectAllFinder = find.text('Select All');
    expect(selectAllFinder, findsOneWidget);
    expect(find.textContaining('0/'), findsOneWidget);

    // Ensure visible and tap Select All again
    await tester.ensureVisible(selectAllFinder);
    await tester.tap(selectAllFinder, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Deselect All'), findsOneWidget);
  });
}
