import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../daily_routine/domain/models/routine_task.dart';
import 'local_schedule_engine.dart';

/// Exception thrown when Groq AI schedule generation fails or returns invalid data.
class GroqScheduleException implements Exception {
  final String message;
  final Object? cause;

  const GroqScheduleException(this.message, [this.cause]);

  @override
  String toString() => cause != null
      ? 'GroqScheduleException: $message ($cause)'
      : 'GroqScheduleException: $message';
}

/// Service providing lightning-fast daily schedule generation powered by Groq Cloud API
/// using `llama-3.3-70b-versatile` with strict JSON mode.
class GroqScheduleService {
  /// Reads the API key passed at compile time via `--dart-define=GROQ_API_KEY=...`
  static const String _apiKey = String.fromEnvironment(
    'GROQ_API_KEY',
    defaultValue: '',
  );

  /// Groq Cloud API endpoint for OpenAI-compatible chat completions.
  static const String _endpoint = 'https://api.groq.com/openai/v1/chat/completions';

  /// Primary Groq model identifier.
  static const String _modelName = 'llama-3.3-70b-versatile';

  /// System instruction enforcing expert schedule creation and JSON schema output.
  static const String _systemInstruction = '''
You are an expert daily schedule and time-management assistant.
Given a user's prompt (commitments, study goals, cooking/meals, workouts):
1. Build a realistic, balanced, 24-hour daily routine.
2. Honor exact user-specified times (e.g. "8:30am to 1pm" must be startHour: 8, startMinute: 30, durationMinutes: 270).
3. Organize meals, prep, learning, and wind-down periods logically.
4. Assign categories: 'Study', 'Health', 'Work', 'Personal'.
5. Sort tasks strictly in chronological order from morning to night.

Return ONLY a JSON object containing a "tasks" array with this schema:
{
  "tasks": [
    {
      "title": "Task Title",
      "category": "Study",
      "startHour": 8,
      "startMinute": 30,
      "durationMinutes": 270
    }
  ]
}
''';

  /// Generates a structured list of proposed routine tasks using Groq's `llama-3.3-70b-versatile`.
  ///
  /// If [_apiKey] is empty or the API call fails, falls back seamlessly to [localScheduleEngine].
  Future<List<Map<String, dynamic>>> generateSchedule(
    String userPrompt, {
    List<RoutineTask>? existingRoutines,
    LocalScheduleEngine? localScheduleEngine,
    String? customApiKey,
  }) async {
    final cleanPrompt = userPrompt.trim();
    if (cleanPrompt.isEmpty) {
      throw const GroqScheduleException('Prompt cannot be empty.');
    }

    final keyToUse = (customApiKey != null && customApiKey.trim().isNotEmpty)
        ? customApiKey.trim()
        : _apiKey;

    // Verify compile-time --dart-define=GROQ_API_KEY
    if (keyToUse.isEmpty) {
      debugPrint(
        'GROQ_API_KEY is not defined. Falling back to on-device LocalScheduleEngine. '
        'Run with --dart-define=GROQ_API_KEY=... to enable remote Groq Llama-3.3 AI.',
      );
      final engine = localScheduleEngine ?? LocalScheduleEngine();
      return engine.parseCustomPrompt(cleanPrompt, existingTasks: existingRoutines);
    }

    final existingSummary = (existingRoutines != null && existingRoutines.isNotEmpty)
        ? existingRoutines
            .map((t) =>
                '- "${t.title}" (${t.category}): starts at ${t.startTime.hour.toString().padLeft(2, '0')}:${t.startTime.minute.toString().padLeft(2, '0')} for ${t.durationMinutes} mins')
            .join('\n')
        : 'No existing routines currently scheduled.';

    final userMessageText = '''
USER SCHEDULE REQUEST:
"$cleanPrompt"

EXISTING SCHEDULED TASKS (AVOID CONFLICTS WITH THESE SLOTS):
$existingSummary

Generate a complete, conflict-free daily routine. Respond ONLY with the structured JSON object.
''';

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $keyToUse',
        },
        body: jsonEncode({
          'model': _modelName,
          'response_format': {'type': 'json_object'},
          'temperature': 0.7,
          'messages': [
            {'role': 'system', 'content': _systemInstruction},
            {'role': 'user', 'content': userMessageText},
          ],
        }),
      );

      if (response.statusCode != 200) {
        debugPrint('Groq API Error HTTP ${response.statusCode}: ${response.body}');
        // Fallback to local engine on API error
        final engine = localScheduleEngine ?? LocalScheduleEngine();
        return engine.parseCustomPrompt(cleanPrompt, existingTasks: existingRoutines);
      }

      final Map<String, dynamic> body = jsonDecode(response.body);
      final choices = body['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw const GroqScheduleException('Groq API returned empty choices array.');
      }

      final message = choices.first['message'] as Map<String, dynamic>?;
      final content = message?['content'] as String?;

      if (content == null || content.trim().isEmpty) {
        throw const GroqScheduleException('Groq API returned empty message content.');
      }

      return _parseJsonResponse(content);
    } catch (e, stackTrace) {
      debugPrint('Error calling Groq API: $e\n$stackTrace');
      if (e is GroqScheduleException) rethrow;
      // Fallback gracefully to LocalScheduleEngine on network or parse failure
      final engine = localScheduleEngine ?? LocalScheduleEngine();
      return engine.parseCustomPrompt(cleanPrompt, existingTasks: existingRoutines);
    }
  }

  /// Cleanly parses and validates the JSON response from Groq.
  List<Map<String, dynamic>> _parseJsonResponse(String responseText) {
    String cleaned = responseText.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned
          .replaceAll(RegExp(r'^```(?:json)?\s*'), '')
          .replaceAll(RegExp(r'\s*```$'), '')
          .trim();
    }

    final dynamic decoded = jsonDecode(cleaned);
    List? rawTaskList;

    if (decoded is List) {
      rawTaskList = decoded;
    } else if (decoded is Map<String, dynamic>) {
      rawTaskList = decoded['tasks'] as List? ??
          decoded['schedule'] as List? ??
          decoded['routines'] as List? ??
          decoded['items'] as List?;
    }

    if (rawTaskList == null) {
      throw const GroqScheduleException('Expected JSON object with "tasks" array from Groq AI.');
    }

    final List<Map<String, dynamic>> tasks = [];

    for (final item in rawTaskList) {
      if (item is! Map<String, dynamic>) continue;

      final title = (item['title'] as String?)?.trim() ?? 'Routine Task';
      final category = _normalizeCategory(item['category'] as String?);
      final startHour = (item['startHour'] as num?)?.toInt().clamp(0, 23) ?? 8;
      final startMinute = (item['startMinute'] as num?)?.toInt().clamp(0, 59) ?? 0;
      final durationMinutes = (item['durationMinutes'] as num?)?.toInt().clamp(15, 480) ?? 60;

      tasks.add({
        'title': title,
        'category': category,
        'startHour': startHour,
        'startMinute': startMinute,
        'durationMinutes': durationMinutes,
      });
    }

    // Sort tasks strictly in chronological order from morning to night
    tasks.sort((a, b) {
      final aMins = (a['startHour'] as int) * 60 + (a['startMinute'] as int);
      final bMins = (b['startHour'] as int) * 60 + (b['startMinute'] as int);
      return aMins.compareTo(bMins);
    });

    return tasks;
  }

  String _normalizeCategory(String? rawCategory) {
    if (rawCategory == null) return 'Personal';
    final lower = rawCategory.trim().toLowerCase();
    if (lower.contains('work')) return 'Work';
    if (lower.contains('health') || lower.contains('fitness') || lower.contains('gym')) {
      return 'Health';
    }
    if (lower.contains('study') || lower.contains('learn') || lower.contains('college')) {
      return 'Study';
    }
    return 'Personal';
  }
}
