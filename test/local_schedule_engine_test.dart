import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nooktime/features/ai_assistant/services/local_schedule_engine.dart';
import 'package:nooktime/features/daily_routine/domain/models/routine_task.dart';

void main() {
  group('LocalScheduleEngine Tests', () {
    late LocalScheduleEngine engine;

    setUp(() {
      engine = LocalScheduleEngine();
    });

    test('parseTimeString handles AM/PM and 24-hour formats correctly', () {
      expect(engine.parseTimeString('8:30am'), equals(const TimeOfDay(hour: 8, minute: 30)));
      expect(engine.parseTimeString('8:30 AM'), equals(const TimeOfDay(hour: 8, minute: 30)));
      expect(engine.parseTimeString('8am'), equals(const TimeOfDay(hour: 8, minute: 0)));
      expect(engine.parseTimeString('1pm'), equals(const TimeOfDay(hour: 13, minute: 0)));
      expect(engine.parseTimeString('1:00 PM'), equals(const TimeOfDay(hour: 13, minute: 0)));
      expect(engine.parseTimeString('10:30pm'), equals(const TimeOfDay(hour: 22, minute: 30)));
      expect(engine.parseTimeString('15:30'), equals(const TimeOfDay(hour: 15, minute: 30)));
    });

    test('getArchetypeSchedule returns exam_prep archetype tasks correctly', () {
      final tasks = engine.getArchetypeSchedule(LocalScheduleEngine.archetypeExamPrep);
      expect(tasks.length, equals(6));

      expect(tasks[0]['title'], equals('Morning Prep & Quick Revision'));
      expect(tasks[0]['category'], equals('Study'));
      expect(tasks[0]['startHour'], equals(8));
      expect(tasks[0]['startMinute'], equals(0));
      expect(tasks[0]['durationMinutes'], equals(45));

      expect(tasks[1]['title'], equals('Deep Focus Study Session'));
      expect(tasks[1]['category'], equals('Study'));
      expect(tasks[1]['startHour'], equals(9));
      expect(tasks[1]['startMinute'], equals(30));
      expect(tasks[1]['durationMinutes'], equals(180));

      expect(tasks[2]['title'], equals('Lunch & Rest'));
      expect(tasks[2]['category'], equals('Health'));
      expect(tasks[2]['startHour'], equals(13));

      expect(tasks[5]['title'], equals('Evening Wind Down'));
      expect(tasks[5]['category'], equals('Personal'));
      expect(tasks[5]['startHour'], equals(22));
      expect(tasks[5]['startMinute'], equals(30));
      expect(tasks[5]['durationMinutes'], equals(30));
    });

    test('getArchetypeSchedule returns healthy_lifestyle archetype tasks correctly', () {
      final tasks = engine.getArchetypeSchedule(LocalScheduleEngine.archetypeHealthyLifestyle);
      expect(tasks.length, equals(6));
      expect(tasks[0]['title'], equals('Morning Exercise & Hydration'));
      expect(tasks[0]['category'], equals('Health'));
      expect(tasks[1]['title'], equals('Core Focus Work'));
      expect(tasks[1]['category'], equals('Work'));
      expect(tasks[1]['durationMinutes'], equals(240));
    });

    test('getArchetypeSchedule returns deep_work archetype tasks correctly', () {
      final tasks = engine.getArchetypeSchedule(LocalScheduleEngine.archetypeDeepWork);
      expect(tasks.length, equals(3));
      expect(tasks[0]['title'], equals('High-Leverage Tasks'));
      expect(tasks[0]['category'], equals('Work'));
      expect(tasks[1]['title'], equals('Focused Execution'));
      expect(tasks[1]['category'], equals('Work'));
      expect(tasks[2]['title'], equals('Inbox & Planning'));
      expect(tasks[2]['category'], equals('Work'));
    });

    test('parseCustomPrompt matches archetype keyword prompt for exam prep', () {
      final tasks = engine.parseCustomPrompt('exam_prep');
      expect(tasks.length, equals(6));
      expect(tasks[0]['title'], equals('Morning Prep & Quick Revision'));
    });

    test('parseCustomPrompt parses college 8:30am to 1pm with exact 270m duration and Study category', () {
      final tasks = engine.parseCustomPrompt('I have college from 8:30am to 1pm and want to learn flutter development and keep a healthy routine');

      final collegeTask = tasks.firstWhere((t) => (t['title'] as String).contains('College'));
      expect(collegeTask['startHour'], equals(8));
      expect(collegeTask['startMinute'], equals(30));
      expect(collegeTask['durationMinutes'], equals(270));
      expect(collegeTask['category'], equals('Study'));

      final flutterTask = tasks.firstWhere((t) => (t['title'] as String).contains('Flutter'));
      expect(flutterTask['title'], equals('Flutter App Development'));
      expect(flutterTask['category'], equals('Study'));
    });

    test('parseCustomPrompt sorts timeline tasks strictly chronologically', () {
      final tasks = engine.parseCustomPrompt('college from 8:30am to 1pm and flutter');
      for (int i = 0; i < tasks.length - 1; i++) {
        final currentMins = (tasks[i]['startHour'] as int) * 60 + (tasks[i]['startMinute'] as int);
        final nextMins = (tasks[i + 1]['startHour'] as int) * 60 + (tasks[i + 1]['startMinute'] as int);
        expect(currentMins <= nextMins, isTrue);
      }
    });

    test('resolveConflicts avoids overlaps with existing scheduled tasks', () {
      final now = DateTime.now();
      final existingTasks = [
        RoutineTask(
          id: '1',
          title: 'Existing Meeting',
          category: 'Work',
          startTime: DateTime(now.year, now.month, now.day, 9, 0),
          durationMinutes: 180, // 09:00 - 12:00
          updatedAt: now,
        ),
      ];

      final tasks = engine.parseCustomPrompt(LocalScheduleEngine.archetypeDeepWork, existingTasks: existingTasks);

      // The task starting at 09:00 (180m) should be shifted to start after 12:00
      final firstTask = tasks[0];
      final firstTaskStartMins = (firstTask['startHour'] as int) * 60 + (firstTask['startMinute'] as int);
      expect(firstTaskStartMins >= 12 * 60, isTrue);
    });
  });
}
