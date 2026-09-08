import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../daily_routine/domain/models/routine_task.dart';
import 'local_ai_learner_service.dart';
import 'local_schedule_engine.dart';

/// Exception thrown when Groq AI Agent schedule generation fails or returns invalid data.
class GroqAiAgentException implements Exception {
  final String message;
  final Object? cause;

  const GroqAiAgentException(this.message, [this.cause]);

  @override
  String toString() => cause != null
      ? 'GroqAiAgentException: $message ($cause)'
      : 'GroqAiAgentException: $message';
}

/// AI Assistant service for generating intelligent, structured daily routine schedules
/// using Groq Cloud API (`llama-3.3-70b-versatile`).
class GroqAiAgentService {
  /// Optional HTTP client for testing or custom connection pools.
  final http.Client _client;

  GroqAiAgentService({http.Client? client}) : _client = client ?? http.Client();

  /// Reads the Groq API key via `--dart-define=GROQ_API_KEY=...`.
  static const String _apiKey = String.fromEnvironment('GROQ_API_KEY');

  /// Target Groq Cloud OpenAI-compatible endpoint.
  static const String _endpoint = 'https://api.groq.com/openai/v1/chat/completions';

  /// Active Groq Cloud model identifiers in order of priority.
  static const List<String> _candidateModels = [
    'llama-3.3-70b-versatile',
    'llama-3.1-8b-instant',
    'llama-3.2-11b-vision-preview',
    'llama-3.2-3b-preview',
  ];

  /// System instructions defining the AI coach persona and strict JSON output requirements.
  static const String _systemInstruction = '''
You are an expert daily schedule and time-management assistant.
Given a user prompt describing commitments, goals, meals, workouts, or specific activities:

1. THINK LIKE A HUMAN BEING:
   - REMEMBER that there are only 24 hours in a day. 
   - DO NOT GENERATE MORE THAN 24 HOURS OF TASKS.
   - BE RATIONAL AND LOGICAL.
   - If the user asks to schedule a task at a specific time, make sure the task does not overlap with any other task.
   - If the user asks to schedule multiple tasks, make sure the tasks do not overlap with each other.
   - THINK LIKE YOU ARE LIVING A REAL WORLD SO CREATE A REALISTIC SCHEDULE.
   - DO NOT OVERLOAD THE USER WITH TOO MANY TASKS.
   - REMEMBER THAT EVERYONE NEEDS TIME FOR REST, RECREATION, AND PERSONAL ACTIVITIES.
   - DO NOT OVERLAP TASKS.
   

2. TARGETED SPECIFIC TASK SCHEDULING VS WHOLE ROUTINE:
   - If the user asks for specific individual tasks or activities, generate ONLY the 1 or 2 requested tasks (or minimal needed tasks). Do NOT generate an entire full-day routine (breakfast, college, sleep, etc.) unless the user explicitly requests a full routine or day plan.
   - If the user asks for a complete routine or goal archetype (e.g., "Full exam prep schedule", "Healthy daily routine"), then generate a complete daily/weekly schedule.

2. EXISTING ROUTINE & FREE TIME SLOT OPTIMIZATION:
   - Review any provided EXISTING SCHEDULED TASKS for target days (1 = Monday ... 7 = Sunday).
   - If free time slots exist on target days (e.g. Saturday [6] and Sunday [7] for weekends), schedule the requested task in an available open slot without conflicting with existing tasks.
   - If no free time slot exists on target days, reschedule or fit the task into an optimal daytime window.

3. STRICT DAYTIME AWAKE HOURS (NEVER SCHEDULE OVERNIGHT TASKS):
   - All tasks MUST strictly be scheduled during daytime awake hours (between 06:00 AM and 12:00 AM / 00:00 AM).
   - NEVER schedule any task overnight (between 01:00 / 1:00 AM and 06:00 / 6:00 AM) UNLESS the user explicitly asks for night/overnight tasks (e.g. "night shift", "late night study at 1am", "overnight build").

4. DAYS OF WEEK ASSIGNMENT:
   - Every task MUST include an explicit "daysOfWeek" list of integers [1..7] (1 = Mon, 6 = Sat, 7 = Sun).
   - "weekends" -> daysOfWeek: [6, 7].
   - "weekdays" -> daysOfWeek: [1, 2, 3, 4, 5].
   - "daily" or "everyday" -> daysOfWeek: [1, 2, 3, 4, 5, 6, 7].

5. STRICT 24-HOUR MILITARY TIME & CATEGORIES:
   - startHour (0..23), startMinute (0..59), durationMinutes (> 0).
   - Categories MUST strictly be one of: 'Study', 'Health', 'Work', 'Personal'.

Return ONLY a valid, raw JSON object containing a "tasks" array. Do NOT output any introductory text, explanation, or conversational commentary.
{
  "tasks": [
    {
      "title": "Japanese Language Study",
      "category": "Study",
      "startHour": 14,
      "startMinute": 0,
      "durationMinutes": 120,
      "daysOfWeek": [6, 7]
    }
  ]
}
''';

  /// Refines an existing schedule based on a conversational refinement prompt [instruction]
  /// and current staged tasks [currentTasks].
  Future<List<Map<String, dynamic>>> refineExistingSchedule(
    List<RoutineTask> currentTasks,
    String instruction, {
    LocalScheduleEngine? localScheduleEngine,
    String? customApiKey,
    String? userProfileContext,
  }) async {
    final cleanInstruction = instruction.trim();
    if (cleanInstruction.isEmpty) {
      throw const GroqAiAgentException('Refinement instruction cannot be empty.');
    }

    final stagedSummary = currentTasks.isNotEmpty
        ? currentTasks
            .map((t) =>
                '- "${t.title}" (${t.category}): start ${t.startTime.hour.toString().padLeft(2, '0')}:${t.startTime.minute.toString().padLeft(2, '0')}, duration ${t.durationMinutes}m, days: ${t.daysOfWeek.join(',')}')
            .join('\n')
        : 'No current staged tasks.';

    final refinementPrompt = '''
CURRENT SCHEDULED STAGED TASKS:
$stagedSummary

USER REFINEMENT INSTRUCTION:
"$cleanInstruction"

Please update, modify, add, or delete tasks according to the user instruction while maintaining the rest of the schedule intact. Return ONLY the updated JSON array of tasks.
''';

    return generateRoutine(
      refinementPrompt,
      existingRoutines: currentTasks,
      localScheduleEngine: localScheduleEngine,
      customApiKey: customApiKey,
      userProfileContext: userProfileContext,
    );
  }

  /// Generates a structured list of proposed routine tasks based on [userPrompt]
  /// and optional [existingRoutines].
  ///
  /// Alias for [generateRoutine].
  Future<List<Map<String, dynamic>>> generateRoutineFromPrompt(
    String userPrompt, {
    List<RoutineTask>? existingRoutines,
    LocalScheduleEngine? localScheduleEngine,
    String? customApiKey,
    String? userProfileContext,
  }) =>
      generateRoutine(
        userPrompt,
        existingRoutines: existingRoutines,
        localScheduleEngine: localScheduleEngine,
        customApiKey: customApiKey,
        userProfileContext: userProfileContext,
      );

  /// Generates a structured list of proposed routine tasks based on [userPrompt],
  /// optional [existingRoutines], and optional [userProfileContext].
  ///
  /// Uses [_apiKey] (or [customApiKey] if provided) with active Groq Cloud models.
  /// Falls back gracefully to [localScheduleEngine] if offline or on error.
  Future<List<Map<String, dynamic>>> generateRoutine(
    String userPrompt, {
    List<RoutineTask>? existingRoutines,
    LocalScheduleEngine? localScheduleEngine,
    String? customApiKey,
    String? userProfileContext,
  }) async {
    final cleanPrompt = userPrompt.trim();
    if (cleanPrompt.isEmpty) {
      throw const GroqAiAgentException('Prompt cannot be empty.');
    }

    final keyToUse = (customApiKey != null && customApiKey.trim().isNotEmpty)
        ? customApiKey.trim()
        : _apiKey;

    if (keyToUse.isEmpty) {
      debugPrint('GROQ_API_KEY is not defined. Falling back to on-device LocalScheduleEngine.');
      final engine = localScheduleEngine ?? LocalScheduleEngine();
      return engine.parseCustomPrompt(cleanPrompt, existingTasks: existingRoutines);
    }

    final existingSummary = (existingRoutines != null && existingRoutines.isNotEmpty)
        ? existingRoutines
            .map((t) =>
                '- "${t.title}" (${t.category}): starts at ${t.startTime.hour.toString().padLeft(2, '0')}:${t.startTime.minute.toString().padLeft(2, '0')} for ${t.durationMinutes} mins')
            .join('\n')
        : 'No existing routines currently scheduled.';

    final profileSection = (userProfileContext != null && userProfileContext.trim().isNotEmpty)
        ? '\n$userProfileContext\n'
        : '';

    final userMessageText = '''
USER SCHEDULE REQUEST:
"$cleanPrompt"
$profileSection
EXISTING SCHEDULED TASKS (AVOID CONFLICTS WITH THESE SLOTS):
$existingSummary

Generate a complete, conflict-free daily routine. Respond ONLY with the structured JSON object.
''';

    String? lastHttpError;

    // Dynamically query active models from Groq Cloud if available
    List<String> activeModels = List.from(_candidateModels);
    try {
      final modelsResponse = await _client.get(
        Uri.parse('https://api.groq.com/openai/v1/models'),
        headers: {'Authorization': 'Bearer $keyToUse'},
      );
      if (modelsResponse.statusCode == 200) {
        final Map<String, dynamic> modelsData = jsonDecode(modelsResponse.body);
        final dataList = modelsData['data'] as List?;
        if (dataList != null && dataList.isNotEmpty) {
          final fetchedIds = dataList
              .map((item) => item['id'] as String?)
              .whereType<String>()
              .where((id) =>
                  !id.contains('whisper') &&
                  !id.contains('vision') &&
                  !id.contains('audio') &&
                  !id.contains('guard') &&
                  !id.contains('safeguard') &&
                  !id.contains('orpheus'))
              .toList();
          if (fetchedIds.isNotEmpty) {
            activeModels = fetchedIds;
            debugPrint('Discovered ${activeModels.length} active Groq chat models dynamically: $activeModels');
          }
        }
      } else {
        lastHttpError = 'HTTP ${modelsResponse.statusCode}: ${modelsResponse.body}';
      }
    } catch (e) {
      debugPrint('Failed to query dynamic Groq models list: $e');
    }

    for (final modelName in activeModels) {
      try {
        debugPrint('Attempting Groq model: $modelName');
        final response = await _client.post(
          Uri.parse(_endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $keyToUse',
          },
          body: jsonEncode({
            'model': modelName,
            'max_tokens': 2048,
            'temperature': 0.1,
            'messages': [
              {'role': 'system', 'content': _systemInstruction},
              {'role': 'user', 'content': userMessageText},
            ],
          }),
        );

        if (response.statusCode == 200) {
          final Map<String, dynamic> body = jsonDecode(response.body);
          final choices = body['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final message = choices.first['message'] as Map<String, dynamic>?;
            final content = message?['content'] as String?;

            if (content != null && content.trim().isNotEmpty) {
              final parsed = await compute(_parseJsonResponseIsolate, content);
              if (parsed.isNotEmpty) {
                _distillPatternLocally(cleanPrompt, parsed);
                return parsed;
              }
            }
          }
        } else {
          lastHttpError = 'HTTP ${response.statusCode}: ${response.body}';
          debugPrint('Groq model $modelName returned $lastHttpError');
        }
      } catch (e) {
        lastHttpError = e.toString();
        debugPrint('Groq model $modelName attempt failed: $e');
      }
    }

    debugPrint('All Groq AI models failed ($lastHttpError).');
    
    // If an explicit API key was provided or configured and API failed with an HTTP error,
    // throw GroqAiAgentException so the user/UI knows Groq failed rather than silently masking it.
    if (lastHttpError != null) {
      throw GroqAiAgentException('Groq Cloud API failed: $lastHttpError');
    }

    try {
      final learner = await LocalAiLearnerService.create();
      final synthesized = await learner.synthesizeLocallyFromPatterns(cleanPrompt);
      return synthesized.map((t) => {
        'title': t.title,
        'category': t.category,
        'startHour': t.startTime.hour,
        'startMinute': t.startTime.minute,
        'durationMinutes': t.durationMinutes,
        'daysOfWeek': t.daysOfWeek,
        'isLearnedLocalAi': true,
      }).toList();
    } catch (_) {
      final engine = localScheduleEngine ?? LocalScheduleEngine();
      final tasks = engine.parseCustomPrompt(cleanPrompt, existingTasks: existingRoutines);
      return tasks.map((t) => {...t, 'isLearnedLocalAi': true}).toList();
    }
  }

  /// Background isolate JSON decoding helper for RoutineTasks.
  static List<RoutineTask> parseTasksIsolate(String rawJson) {
    final Map<String, dynamic> data = jsonDecode(rawJson);
    final List tasks = data['tasks'] as List? ?? [];
    return tasks.map((e) => RoutineTask.fromMap(e as Map<String, dynamic>)).toList();
  }

  /// Offloads JSON schedule parsing to a background compute() isolate.
  static List<Map<String, dynamic>> _parseJsonResponseIsolate(String responseText) {
    final service = GroqAiAgentService();
    return service._parseJsonResponse(responseText);
  }

  /// Cleanly parses and validates the JSON response body returned by Groq AI.
  List<Map<String, dynamic>> _parseJsonResponse(String responseText) {
    String cleaned = responseText.trim();
    
    // Strip reasoning <think>...</think> blocks generated by reasoning models (e.g. Qwen / DeepSeek)
    if (cleaned.contains('</think>')) {
      cleaned = cleaned.split('</think>').last.trim();
    } else if (cleaned.startsWith('<think>')) {
      final closingIdx = cleaned.indexOf('</think>');
      if (closingIdx != -1) {
        cleaned = cleaned.substring(closingIdx + 8).trim();
      }
    }
    
    if (cleaned.startsWith('```')) {
      cleaned = cleaned
          .replaceAll(RegExp(r'^```(?:json)?\s*'), '')
          .replaceAll(RegExp(r'\s*```$'), '')
          .trim();
    }
    
    // Extract JSON object substring if model outputs leading/trailing commentary
    final firstBrace = cleaned.indexOf('{');
    final lastBrace = cleaned.lastIndexOf('}');
    if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
      cleaned = cleaned.substring(firstBrace, lastBrace + 1).trim();
    } else {
      final firstBracket = cleaned.indexOf('[');
      final lastBracket = cleaned.lastIndexOf(']');
      if (firstBracket != -1 && lastBracket != -1 && lastBracket > firstBracket) {
        cleaned = cleaned.substring(firstBracket, lastBracket + 1).trim();
      }
    }

    // Strip trailing commas before closing brackets/braces (e.g. `,"category": "Work",]}`)
    cleaned = cleaned.replaceAll(RegExp(r',\s*([\]\}])'), r'$1');

    dynamic decoded;
    try {
      decoded = jsonDecode(cleaned);
    } catch (_) {
      try {
        var candidate = cleaned;
        
        // Strip trailing comma inside array/object at end of string
        candidate = candidate.replaceAll(RegExp(r',\s*$'), '');

        // Balance open brackets and braces if response truncated at token limit
        int openBraces = 0;
        int openBrackets = 0;
        bool inString = false;
        
        for (int i = 0; i < candidate.length; i++) {
          final char = candidate[i];
          if (char == '"' && (i == 0 || candidate[i - 1] != '\\')) {
            inString = !inString;
          } else if (!inString) {
            if (char == '{') openBraces++;
            if (char == '}') openBraces--;
            if (char == '[') openBrackets++;
            if (char == ']') openBrackets--;
          }
        }

        if (inString) {
          candidate += '"';
        }
        candidate = candidate.replaceAll(RegExp(r',\s*$'), '');
        
        while (openBrackets > 0) {
          candidate += ']';
          openBrackets--;
        }
        while (openBraces > 0) {
          candidate += '}';
          openBraces--;
        }

        candidate = candidate.replaceAll(RegExp(r',\s*([\]\}])'), r'$1');
        decoded = jsonDecode(candidate);
      } catch (e2) {
        throw GroqAiAgentException('Failed to parse JSON response from Groq AI: $e2');
      }
    }
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
      throw const GroqAiAgentException('Expected JSON object with "tasks" array from Groq AI.');
    }

    final List<Map<String, dynamic>> tasks = [];

    for (final item in rawTaskList) {
      if (item is! Map<String, dynamic>) continue;

      final title = (item['title'] as String?)?.trim() ?? 'Routine Task';
      final category = _normalizeCategory(item['category'] as String?);
      final startHour = (item['startHour'] as num?)?.toInt().clamp(0, 23) ?? 8;
      final startMinute = (item['startMinute'] as num?)?.toInt().clamp(0, 59) ?? 0;
      final durationMinutes = (item['durationMinutes'] as num?)?.toInt().clamp(15, 480) ?? 60;

      final rawDays = item['daysOfWeek'] as List<dynamic>?;
      final List<int> daysOfWeek = (rawDays != null && rawDays.isNotEmpty)
          ? rawDays
              .map((e) => int.tryParse(e.toString()) ?? 1)
              .where((d) => d >= 1 && d <= 7)
              .toList()
          : <int>[1, 2, 3, 4, 5, 6, 7];

      final finalDays = daysOfWeek.isNotEmpty
          ? daysOfWeek
          : const <int>[1, 2, 3, 4, 5, 6, 7];

      tasks.add({
        'title': title,
        'category': category,
        'startHour': startHour,
        'startMinute': startMinute,
        'durationMinutes': durationMinutes,
        'daysOfWeek': finalDays,
      });
    }

    // Sort tasks strictly in chronological order from morning to night
    tasks.sort((a, b) {
      final aMins = (a['startHour'] as int) * 60 + (a['startMinute'] as int);
      final bMins = (b['startHour'] as int) * 60 + (b['startMinute'] as int);
      return aMins.compareTo(bMins);
    });

    // Post-processing Conflict & Overlap Resolver:
    // Pushes conflicting/overlapping task start times so every task starts cleanly after previous finishes.
    for (int i = 0; i < tasks.length - 1; i++) {
      final currentStartMins = (tasks[i]['startHour'] as int) * 60 + (tasks[i]['startMinute'] as int);
      final currentDuration = tasks[i]['durationMinutes'] as int;
      final currentEndMins = currentStartMins + currentDuration;

      final nextStartMins = (tasks[i + 1]['startHour'] as int) * 60 + (tasks[i + 1]['startMinute'] as int);

      if (nextStartMins < currentEndMins && currentEndMins < 1440) {
        final newNextStartHour = (currentEndMins ~/ 60) % 24;
        final newNextStartMinute = currentEndMins % 60;
        tasks[i + 1]['startHour'] = newNextStartHour;
        tasks[i + 1]['startMinute'] = newNextStartMinute;
      }
    }

    // Re-sort after overlap resolution
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

  /// Asynchronously distills Groq's high-quality response into on-device LocalAiLearnerService storage.
  void _distillPatternLocally(String prompt, List<Map<String, dynamic>> tasks) {
    LocalAiLearnerService.create().then((learner) {
      learner.learnFromGroqResponse(prompt: prompt, tasks: tasks);
    }).catchError((e) {
      debugPrint('Local AI distillation notice: $e');
    });
  }
}
