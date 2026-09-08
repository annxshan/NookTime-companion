import 'package:flutter_test/flutter_test.dart';
import 'package:nooktime/features/ai_assistant/services/gemini_schedule_service.dart';
import 'package:nooktime/features/daily_routine/domain/models/routine_task.dart';

void main() {
  group('GeminiScheduleService Tests', () {
    final service = GeminiScheduleService();

    test('generateSchedule throws GeminiScheduleException when apiKey is empty', () async {
      expect(
        () => service.generateSchedule(
          userPrompt: 'Build an morning routine',
          existingRoutines: [],
          apiKey: '',
        ),
        throwsA(isA<GeminiScheduleException>()),
      );
    });

    test('generateSchedule throws GeminiScheduleException when apiKey is whitespace', () async {
      expect(
        () => service.generateSchedule(
          userPrompt: 'Study schedule',
          existingRoutines: [
            RoutineTask(
              id: '1',
              title: 'Reading',
              category: 'Study',
              startTime: DateTime.now(),
              durationMinutes: 30,
              updatedAt: DateTime.now(),
            )
          ],
          apiKey: '   ',
        ),
        throwsA(isA<GeminiScheduleException>()),
      );
    });
  });
}
