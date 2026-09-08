import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nooktime/features/ai_assistant/services/groq_ai_agent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _TestHttpOverrides();

  test('GroqAiAgentService generates routine from Groq API', () async {
    SharedPreferences.setMockInitialValues({});
    
    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/models')) {
        return http.Response(
          jsonEncode({
            'data': [
              {'id': 'llama-3.3-70b-versatile'}
            ]
          }),
          200,
        );
      }
      
      return http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {
                'content': jsonEncode({
                  'tasks': [
                    {
                      'title': 'Study for Exam',
                      'category': 'Study',
                      'startHour': 14,
                      'startMinute': 0,
                      'durationMinutes': 180,
                      'daysOfWeek': [1, 2, 3, 4, 5]
                    }
                  ]
                })
              }
            }
          ]
        }),
        200,
      );
    });

    final service = GroqAiAgentService(client: mockClient);

    final tasks = await service.generateRoutineFromPrompt(
      'Exam next week, add 3 hours study and keep 1 hour for gym',
    );

    expect(tasks, isNotEmpty);
    expect(tasks.first, contains('title'));
    expect(tasks.first, contains('category'));
    expect(tasks.first, contains('startHour'));
    expect(tasks.first, contains('daysOfWeek'));
  });
}
