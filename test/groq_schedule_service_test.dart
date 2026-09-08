import 'package:flutter_test/flutter_test.dart';
import 'package:nooktime/features/ai_assistant/services/groq_schedule_service.dart';

void main() {
  group('GroqScheduleService Unit Tests', () {
    late GroqScheduleService service;

    setUp(() {
      service = GroqScheduleService();
    });

    test('generateSchedule throws GroqScheduleException when prompt is empty', () async {
      expect(
        () => service.generateSchedule(''),
        throwsA(isA<GroqScheduleException>()),
      );
    });

    test('generateSchedule falls back gracefully to LocalScheduleEngine when GROQ_API_KEY is empty', () async {
      final tasks = await service.generateSchedule(
        'I have college from 8:30am to 1pm and want to learn flutter',
      );

      expect(tasks.isNotEmpty, isTrue);
      final collegeTask = tasks.firstWhere((t) => (t['title'] as String).contains('College'));
      expect(collegeTask['startHour'], equals(8));
      expect(collegeTask['startMinute'], equals(30));
      expect(collegeTask['durationMinutes'], equals(270));
    });
  });
}
