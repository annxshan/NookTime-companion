import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../../daily_routine/domain/models/routine_task.dart';
import 'local_schedule_engine.dart';

/// Exception thrown when Gemini AI schedule generation fails or returns invalid data.
class GeminiAiAgentException implements Exception {
  final String message;
  final Object? cause;

  const GeminiAiAgentException(this.message, [this.cause]);

  @override
  String toString() => cause != null
      ? 'GeminiAiAgentException: $message ($cause)'
      : 'GeminiAiAgentException: $message';
}

/// AI Assistant service reading the Gemini API Key from environment variables via `--dart-define=GEMINI_API_KEY=...`
/// and generating structured JSON daily routine schedules.
class GeminiAiAgentService {
  /// Reads the API key passed at compile time via `--dart-define=GEMINI_API_KEY=...`
  static const String _apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  /// Primary and fallback model identifiers to try sequentially.
  static const List<String> _candidateModels = [
    'gemini-2.5-flash',
    'gemini-1.5-flash-8b',
    'gemini-1.5-pro',
    'gemini-2.0-flash-exp',
    'gemini-1.5-flash',
  ];

  /// System instructions defining the AI agent persona and strict JSON output requirements.
  static const String _systemInstruction = '''
You are an expert daily schedule and time-management assistant.
Given a user's prompt (commitments, study goals, cooking/meals, workouts):
1. Build a realistic, balanced, 24-hour daily routine.
2. Honor exact user-specified times (e.g. "8:30am to 1pm" must be startHour: 8, startMinute: 30, durationMinutes: 270).
3. Organize meals, prep, learning, and wind-down periods logically.
4. Assign categories: 'Study', 'Health', 'Work', 'Personal'.
5. Sort tasks strictly in chronological order from morning to night.

Return ONLY a JSON array with this schema:
[
  {
    "title": "Task Title",
    "category": "Study",
    "startHour": 8,
    "startMinute": 30,
    "durationMinutes": 270
  }
]
''';

  /// Generates a structured list of proposed routine tasks based on [promptText]
  /// and optional [existingRoutines].
  ///
  /// Verifies that [_apiKey] is non-empty or falls back gracefully to [localScheduleEngine].
  Future<List<Map<String, dynamic>>> generateRoutine(
    String promptText, {
    List<RoutineTask>? existingRoutines,
    LocalScheduleEngine? localScheduleEngine,
  }) async {
    final cleanPrompt = promptText.trim();
    if (cleanPrompt.isEmpty) {
      throw const GeminiAiAgentException('Prompt cannot be empty.');
    }

    // Verify compile-time --dart-define=GEMINI_API_KEY
    if (_apiKey.isEmpty) {
      debugPrint(
        'GEMINI_API_KEY is not defined. Falling back to on-device LocalScheduleEngine. '
        'Run with --dart-define=GEMINI_API_KEY=... to enable remote Gemini AI.',
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

    final fullPrompt = '''
USER SCHEDULE REQUEST:
"$cleanPrompt"

EXISTING SCHEDULED TASKS (AVOID CONFLICTS WITH THESE SLOTS):
$existingSummary

Generate a complete, conflict-free daily routine. Respond ONLY with the JSON array.
''';

    // Try candidate models sequentially
    for (final modelName in _candidateModels) {
      try {
        final model = GenerativeModel(
          model: modelName,
          apiKey: _apiKey,
          systemInstruction: Content.system(_systemInstruction),
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
            temperature: 0.7,
          ),
        );

        final response = await model.generateContent([Content.text(fullPrompt)]);
        final responseText = response.text;

        if (responseText != null && responseText.trim().isNotEmpty) {
          return _parseJsonResponse(responseText);
        }
      } catch (e) {
        debugPrint('Gemini model "$modelName" attempt failed: $e');
        // Continue to try next candidate model
      }
    }

    // If all Gemini remote API calls fail or throw errors, fallback gracefully to LocalScheduleEngine
    debugPrint('All Gemini API models failed. Falling back to on-device LocalScheduleEngine.');
    final engine = localScheduleEngine ?? LocalScheduleEngine();
    return engine.parseCustomPrompt(cleanPrompt, existingTasks: existingRoutines);
  }

  /// Parses JSON array returned by the Gemini AI model.
  List<Map<String, dynamic>> _parseJsonResponse(String responseText) {
    String cleaned = responseText.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned
          .replaceAll(RegExp(r'^```(?:json)?\s*'), '')
          .replaceAll(RegExp(r'\s*```$'), '')
          .trim();
    }

    final dynamic decoded = jsonDecode(cleaned);
    if (decoded is! List) {
      throw const GeminiAiAgentException('Expected JSON array response from AI agent.');
    }

    final List<Map<String, dynamic>> tasks = [];

    for (final item in decoded) {
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
