import 'package:flutter_test/flutter_test.dart';
import 'package:nooktime/features/ai_assistant/services/local_ai_learner_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalAiLearnerService Tests', () {
    late LocalAiLearnerService learnerService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      learnerService = await LocalAiLearnerService.create();
    });

    test('learnFromGroqResponse stores pattern signature into local storage', () async {
      const prompt = 'College from 8:30am to 1pm, study flutter, sleep at 11pm';
      final tasks = [
        {
          'title': 'College / Classes',
          'category': 'Study',
          'startHour': 8,
          'startMinute': 30,
          'durationMinutes': 270,
          'daysOfWeek': [1, 2, 3, 4, 5, 6],
        },
        {
          'title': 'Flutter Practice',
          'category': 'Study',
          'startHour': 16,
          'startMinute': 0,
          'durationMinutes': 120,
          'daysOfWeek': [1, 2, 3, 4, 5, 6, 7],
        },
      ];

      await learnerService.learnFromGroqResponse(
        prompt: prompt,
        tasks: tasks,
      );

      // Verify offline synthesis uses learned pattern
      final synthesized = await learnerService.synthesizeLocallyFromPatterns('study flutter');
      expect(synthesized.isNotEmpty, isTrue);
      expect(synthesized.any((t) => t.title.contains('Flutter') || t.title.contains('College')), isTrue);
    });

    test('synthesizeLocallyFromPatterns returns fallback routines when no patterns exist', () async {
      final routines = await learnerService.synthesizeLocallyFromPatterns('random prompt');
      expect(routines.isNotEmpty, isTrue);
      expect(routines.first.title, isNotEmpty);
    });
  });
}
