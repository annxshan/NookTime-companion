import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../../daily_routine/domain/models/routine_task.dart';

/// Exception thrown when Gemini AI schedule generation fails or returns invalid data.
class GeminiScheduleException implements Exception {
  final String message;
  final Object? cause;

  const GeminiScheduleException(this.message, [this.cause]);

  @override
  String toString() => cause != null
      ? 'GeminiScheduleException: $message ($cause)'
      : 'GeminiScheduleException: $message';
}

/// AI Assistant service for generating intelligent, conflict-free routine schedules
/// using Google's Gemini API (`gemini-2.5-flash`).
class GeminiScheduleService {
  /// Default model identifier.
  static const String _modelName = 'gemini-2.5-flash';

  /// Default Gemini API Key (empty until user pastes their AI Studio key starting with AIzaSy...).
  static const String defaultApiKey = '';

  /// System instructions defining the AI persona and strict output requirements.
  static const String _systemInstruction = '''
You are an expert personal productivity, routine, and habit coach for Nooktime.
Your goal is to design realistic, healthy, and highly effective daily routine schedules based on the user's specific request.

CRITICAL CONSTRAINTS:
1. Review the list of existing tasks provided in the prompt to avoid overlapping start times and durations.
2. Produce realistic time slots between 06:00 and 22:00.
3. Categorize every task into exactly one of: "Work", "Health", "Study", or "Personal".
4. You MUST respond with ONLY a valid JSON array of schedule objects. Do not include markdown code fences, backticks, commentary, or prose.

JSON Schema format:
[
  {
    "title": "Task or habit name",
    "category": "Work | Health | Study | Personal",
    "startHour": 7,
    "startMinute": 0,
    "durationMinutes": 30
  }
]
''';

  /// Generates a structured list of proposed routine tasks based on [userPrompt]
  /// and current [existingRoutines].
  ///
  /// Uses [apiKey] or falls back to [defaultApiKey] if empty.
  Future<List<Map<String, dynamic>>> generateSchedule({
    required String userPrompt,
    required List<RoutineTask> existingRoutines,
    String? apiKey,
  }) async {
    final String keyToUse = (apiKey != null && apiKey.trim().isNotEmpty)
        ? apiKey.trim()
        : defaultApiKey;

    if (keyToUse.isEmpty) {
      throw const GeminiScheduleException(
        'Gemini API key is required. Please paste your key (starts with "AIzaSy...") from Google AI Studio.',
      );
    }

    try {
      final model = GenerativeModel(
        model: _modelName,
        apiKey: keyToUse,
        systemInstruction: Content.system(_systemInstruction),
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.7,
        ),
      );

      final existingRoutinesSummary = existingRoutines.isEmpty
          ? 'No existing routines currently scheduled.'
          : existingRoutines
              .map((t) =>
                  '- "${t.title}" (${t.category}): starts at ${t.startTime.hour.toString().padLeft(2, '0')}:${t.startTime.minute.toString().padLeft(2, '0')} for ${t.durationMinutes} mins')
              .join('\n');

      final fullPrompt = '''
USER REQUEST:
"$userPrompt"

EXISTING SCHEDULED TASKS (AVOID OVERLAPPING WITH THESE TIME SLOTS):
$existingRoutinesSummary

Generate a list of conflict-free routine tasks for today matching the user's request.
Respond with ONLY the JSON array.
''';

      final response = await model.generateContent([Content.text(fullPrompt)]);
      final responseText = response.text;

      if (responseText == null || responseText.trim().isEmpty) {
        throw const GeminiScheduleException(
            'Received empty response from Gemini AI.');
      }

      return _parseJsonResponse(responseText);
    } on GenerativeAIException catch (e) {
      debugPrint('Gemini API Error: $e');
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid authentication credentials') ||
          msg.contains('api key not valid') ||
          msg.contains('unauthorized')) {
        throw const GeminiScheduleException(
          'Invalid Gemini API Key. Google Gemini API keys start with "AIzaSy...". Please create a free key at aistudio.google.com and paste it in the key field.',
        );
      }
      throw GeminiScheduleException('Gemini AI error: ${e.message}', e);
    } catch (e, stackTrace) {
      debugPrint('Unexpected error in GeminiScheduleService: $e\n$stackTrace');
      if (e is GeminiScheduleException) rethrow;
      throw GeminiScheduleException(
          'Failed to generate schedule: ${e.toString()}', e);
    }
  }

  /// Cleanly parses and validates the JSON response from Gemini.
  List<Map<String, dynamic>> _parseJsonResponse(String responseText) {
    try {
      // Defensive cleaning: strip ```json ... ``` markdown backticks if present
      String cleanedText = responseText.trim();
      if (cleanedText.startsWith('```')) {
        cleanedText = cleanedText
            .replaceAll(RegExp(r'^```(?:json)?\s*'), '')
            .replaceAll(RegExp(r'\s*```$'), '')
            .trim();
      }

      final dynamic decoded = jsonDecode(cleanedText);

      if (decoded is! List) {
        throw const FormatException('Expected top-level JSON array.');
      }

      final List<Map<String, dynamic>> tasks = [];

      for (final item in decoded) {
        if (item is! Map<String, dynamic>) continue;

        final title = (item['title'] as String?)?.trim() ?? 'New Habit';
        final category = _normalizeCategory(item['category'] as String?);
        final startHour = (item['startHour'] as num?)?.toInt().clamp(0, 23) ?? 8;
        final startMinute = (item['startMinute'] as num?)?.toInt().clamp(0, 59) ?? 0;
        final durationMinutes =
            (item['durationMinutes'] as num?)?.toInt().clamp(15, 360) ?? 30;

        tasks.add({
          'title': title,
          'category': category,
          'startHour': startHour,
          'startMinute': startMinute,
          'durationMinutes': durationMinutes,
        });
      }

      if (tasks.isEmpty) {
        throw const GeminiScheduleException(
            'AI response did not contain any valid task objects.');
      }

      return tasks;
    } on FormatException catch (e) {
      throw GeminiScheduleException(
          'Invalid JSON returned by AI model: ${e.message}', e);
    }
  }

  String _normalizeCategory(String? category) {
    if (category == null) return 'Personal';
    final lower = category.trim().toLowerCase();
    if (lower.contains('work')) return 'Work';
    if (lower.contains('health') || lower.contains('fitness') || lower.contains('exercise')) {
      return 'Health';
    }
    if (lower.contains('study') || lower.contains('learn') || lower.contains('read')) {
      return 'Study';
    }
    return 'Personal';
  }
}
