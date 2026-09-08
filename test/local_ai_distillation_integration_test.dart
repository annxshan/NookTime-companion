import 'package:flutter_test/flutter_test.dart';
import 'package:nooktime/features/ai_assistant/services/local_ai_learner_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Local AI Learning & Groq Distillation Integration Test', () {
    late LocalAiLearnerService learnerService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      learnerService = await LocalAiLearnerService.create();
    });

    test('Local AI learns Groq pattern and synthesizes offline matching schedule', () async {
      const userPrompt = 'College from 8:30am to 1pm, study flutter, sleep at 11pm';

      // 1. Simulate Groq AI response
      final groqGeneratedTasks = [
        {
          'title': 'College / Classes',
          'category': 'Study',
          'startHour': 8,
          'startMinute': 30,
          'durationMinutes': 270,
          'daysOfWeek': [1, 2, 3, 4, 5, 6],
        },
        {
          'title': 'Flutter Coding Practice',
          'category': 'Study',
          'startHour': 16,
          'startMinute': 0,
          'durationMinutes': 120,
          'daysOfWeek': [1, 2, 3, 4, 5, 6, 7],
        },
        {
          'title': 'Sleep & Recharge',
          'category': 'Health',
          'startHour': 23,
          'startMinute': 0,
          'durationMinutes': 480,
          'daysOfWeek': [1, 2, 3, 4, 5, 6, 7],
        },
      ];

      // 2. Distill Groq response into Local AI Learner
      await learnerService.learnFromGroqResponse(
        prompt: userPrompt,
        tasks: groqGeneratedTasks,
      );

      // 3. Test offline synthesis for a similar prompt
      const offlinePrompt = 'study flutter and college at 8:30am';
      final offlineSynthesizedTasks = await learnerService.synthesizeLocallyFromPatterns(offlinePrompt);

      // 4. Assertions
      expect(offlineSynthesizedTasks, isNotEmpty);
      expect(offlineSynthesizedTasks.any((t) => t.title.toLowerCase().contains('college') || t.title.toLowerCase().contains('flutter')), isTrue);
      
      // Check time anchor extraction (8:30am)
      final collegeTask = offlineSynthesizedTasks.firstWhere((t) => t.title.toLowerCase().contains('college'));
      expect(collegeTask.startTime.hour, equals(8));
      expect(collegeTask.startTime.minute, equals(30));
    });
  });
}
