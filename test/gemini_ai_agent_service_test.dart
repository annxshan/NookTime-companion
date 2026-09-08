import 'package:flutter_test/flutter_test.dart';
import 'package:nooktime/features/ai_assistant/services/gemini_ai_agent_service.dart';
import 'package:nooktime/features/ai_assistant/services/local_schedule_engine.dart';

void main() {
  group('GeminiAiAgentService Tests', () {
    late GeminiAiAgentService service;
    late LocalScheduleEngine localEngine;

    setUp(() {
      service = GeminiAiAgentService();
      localEngine = LocalScheduleEngine();
    });

    test('generateRoutine throws GeminiAiAgentException when prompt is empty', () async {
      expect(
        () => service.generateRoutine(''),
        throwsA(isA<GeminiAiAgentException>()),
      );
    });

    test('generateRoutine falls back gracefully to LocalScheduleEngine when GEMINI_API_KEY is empty', () async {
      final tasks = await service.generateRoutine(
        'I have college from 8:30am to 1pm and want to learn flutter',
        localScheduleEngine: localEngine,
      );

      expect(tasks.isNotEmpty, isTrue);
      final collegeTask = tasks.firstWhere((t) => (t['title'] as String).contains('College'));
      expect(collegeTask['startHour'], equals(8));
      expect(collegeTask['startMinute'], equals(30));
      expect(collegeTask['durationMinutes'], equals(270));
    });
  });
}
