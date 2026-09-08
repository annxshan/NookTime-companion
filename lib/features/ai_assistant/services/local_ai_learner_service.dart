import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../daily_routine/domain/models/routine_task.dart';
import '../../daily_routine/domain/models/task_type.dart';

/// Service responsible for local AI pattern learning and distillation.
/// Captures successful Groq AI completions, vectorizes/indexes prompt semantic tokens,
/// and synthesizes conflict-free routines locally on-device when offline.
class LocalAiLearnerService {
  static const String _prefKeyLearnedPatterns = 'local_ai_learned_patterns';

  final SharedPreferences? _prefs;

  LocalAiLearnerService([this._prefs]);

  static Future<LocalAiLearnerService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalAiLearnerService(prefs);
  }

  /// Extracts keywords/tokens from text for semantic pattern matching.
  List<String> _extractTokens(String text) {
    final clean = text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    final words = clean.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
    const stopWords = {
      'from',
      'with',
      'that',
      'this',
      'have',
      'into',
      'each',
      'every',
      'time',
      'task',
      'routine',
      'and',
      'for',
      'the',
      'you',
      'are'
    };
    return words.where((w) => !stopWords.contains(w)).toSet().toList();
  }

  /// Parses explicit time anchors from prompt text using local regex heuristics.
  /// Matches patterns like "8:30am to 1pm", "college at 9am", "sleep at 11pm".
  List<Map<String, dynamic>> _extractTimeAnchors(String prompt) {
    final anchors = <Map<String, dynamic>>[];
    final text = prompt.toLowerCase();

    final timeRegex = RegExp(
      r'(\b[a-z\s]{3,20}\b)?\s*(?:from|at)?\s*(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\s*(?:to|-)?\s*(?:(\d{1,2})(?::(\d{2}))?\s*(am|pm)?)?',
      caseSensitive: false,
    );

    final matches = timeRegex.allMatches(text);
    for (final m in matches) {
      final keyword = m.group(1)?.trim();
      final startHourRaw = m.group(2);
      if (startHourRaw == null) continue;

      int startHour = int.parse(startHourRaw);
      final startMin = int.tryParse(m.group(3) ?? '0') ?? 0;
      final startPeriod = m.group(4);

      if (startPeriod == 'pm' && startHour < 12) startHour += 12;
      if (startPeriod == 'am' && startHour == 12) startHour = 0;

      int? endHour;
      int? endMin;
      final endHourRaw = m.group(5);
      if (endHourRaw != null) {
        endHour = int.parse(endHourRaw);
        endMin = int.tryParse(m.group(6) ?? '0') ?? 0;
        final endPeriod = m.group(7) ?? startPeriod;
        if (endPeriod == 'pm' && endHour < 12) endHour += 12;
        if (endPeriod == 'am' && endHour == 12) endHour = 0;
      }

      if (keyword != null && keyword.isNotEmpty) {
        anchors.add({
          'keyword': keyword,
          'startHour': startHour,
          'startMinute': startMin,
          'endHour': endHour,
          'endMinute': endMin,
        });
      }
    }
    return anchors;
  }

  /// Learns and vectorizes a pattern signature from a successful Groq, Qwen, Gemini, or Local AI response.
  Future<void> learnFromGroqResponse({
    required String prompt,
    required List<Map<String, dynamic>> tasks,
  }) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();

      final tokens = _extractTokens(prompt);
      final anchors = _extractTimeAnchors(prompt);

      final pattern = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'prompt': prompt,
        'tokens': tokens,
        'anchors': anchors,
        'tasks': tasks,
        'createdAt': DateTime.now().toIso8601String(),
      };

      final existingJson = prefs.getStringList(_prefKeyLearnedPatterns) ?? [];
      final updatedList = List<String>.from(existingJson);

      // Store up to 20 most recent high-quality patterns
      updatedList.insert(0, jsonEncode(pattern));
      if (updatedList.length > 20) {
        updatedList.removeLast();
      }

      await prefs.setStringList(_prefKeyLearnedPatterns, updatedList);
      debugPrint('LocalAiLearnerService: Learned pattern from prompt "$prompt" (${tasks.length} slots)');
    } catch (e) {
      debugPrint('LocalAiLearnerService error in learnFromGroqResponse: $e');
    }
  }

  /// Alias for learning from any AI engine (Groq, Qwen, Gemini, or Local Engine).
  Future<void> learnFromAiCompletion({
    required String prompt,
    required List<Map<String, dynamic>> tasks,
  }) async {
    await learnFromGroqResponse(prompt: prompt, tasks: tasks);
  }

  /// Asynchronously records and distills routine tasks into local pattern memory every time AI generates a schedule.
  static void recordPattern({
    required String prompt,
    required List<RoutineTask> tasks,
  }) {
    if (prompt.trim().isEmpty || tasks.isEmpty) return;

    final taskMaps = tasks.map((t) => {
      'title': t.title,
      'category': t.category,
      'startHour': t.startTime.hour,
      'startMinute': t.startTime.minute,
      'durationMinutes': t.durationMinutes,
      'daysOfWeek': t.daysOfWeek,
    }).toList();

    create().then((learner) {
      learner.learnFromAiCompletion(prompt: prompt, tasks: taskMaps);
    }).catchError((e) {
      debugPrint('Local AI pattern learning notice: $e');
    });
  }

  /// Synthesizes a conflict-free routine locally on-device by interpolating user's
  /// prompt into the closest learned Groq AI patterns.
  Future<List<RoutineTask>> synthesizeLocallyFromPatterns(String userPrompt) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final savedJsonList = prefs.getStringList(_prefKeyLearnedPatterns) ?? [];

      final inputTokens = _extractTokens(userPrompt);
      final userAnchors = _extractTimeAnchors(userPrompt);

      Map<String, dynamic>? bestPattern;
      double bestScore = -1.0;

      // Match prompt against stored patterns using token Jaccard similarity
      for (final jsonStr in savedJsonList) {
        try {
          final pattern = jsonDecode(jsonStr) as Map<String, dynamic>;
          final patternTokens = List<String>.from(pattern['tokens'] ?? []);

          final intersection = inputTokens.where((t) => patternTokens.contains(t)).length;
          final union = (inputTokens.toSet()..addAll(patternTokens)).length;
          final similarity = union > 0 ? intersection / union : 0.0;

          if (similarity > bestScore) {
            bestScore = similarity;
            bestPattern = pattern;
          }
        } catch (_) {}
      }

      final List<Map<String, dynamic>> baseTaskMaps = bestPattern != null
          ? List<Map<String, dynamic>>.from(bestPattern['tasks'] ?? [])
          : _fallbackTemplate();

      final now = DateTime.now();
      final List<RoutineTask> synthesizedTasks = [];

      for (int i = 0; i < baseTaskMaps.length; i++) {
        final rawMap = baseTaskMaps[i];
        final title = (rawMap['title'] as String?) ?? 'Task ${i + 1}';
        final category = (rawMap['category'] as String?) ?? 'Personal';
        int startHour = (rawMap['startHour'] as num?)?.toInt() ?? (8 + i * 2);
        int startMinute = (rawMap['startMinute'] as num?)?.toInt() ?? 0;
        int durationMinutes = (rawMap['durationMinutes'] as num?)?.toInt() ?? 60;

        final rawDays = rawMap['daysOfWeek'] as List?;
        final daysOfWeek = (rawDays != null && rawDays.isNotEmpty)
            ? rawDays.map((e) => (e as num).toInt()).toList()
            : const [1, 2, 3, 4, 5, 6, 7];

        // Override time if prompt explicitly contains an anchor for this category/keyword
        for (final anchor in userAnchors) {
          final kw = anchor['keyword'] as String;
          if (title.toLowerCase().contains(kw) || category.toLowerCase().contains(kw)) {
            startHour = anchor['startHour'] as int;
            startMinute = anchor['startMinute'] as int;
            final endH = anchor['endHour'] as int?;
            final endM = anchor['endMinute'] as int?;
            if (endH != null) {
              final startTotal = startHour * 60 + startMinute;
              final endTotal = endH * 60 + (endM ?? 0);
              if (endTotal > startTotal) {
                durationMinutes = endTotal - startTotal;
              }
            }
            break;
          }
        }

        // Ensure daytime awake hours (06:00 - 22:00) unless explicit overnight requested
        final titleLower = title.toLowerCase();
        final isExplicitOvernight = titleLower.contains('overnight') ||
            titleLower.contains('night shift') ||
            titleLower.contains('late night') ||
            titleLower.contains('1am') ||
            titleLower.contains('2am') ||
            titleLower.contains('3am') ||
            titleLower.contains('4am');

        if (!isExplicitOvernight) {
          if (startHour < 6) startHour = 8;
          if (startHour >= 23) startHour = 14;
        }

        final startTime = DateTime(
          now.year,
          now.month,
          now.day,
          startHour,
          startMinute,
        );

        synthesizedTasks.add(RoutineTask(
          id: '${DateTime.now().millisecondsSinceEpoch}_syn_$i',
          title: title,
          category: category,
          startTime: startTime,
          durationMinutes: durationMinutes,
          type: TaskType.routine,
          isCompleted: false,
          updatedAt: DateTime.now().toUtc(),
          daysOfWeek: daysOfWeek,
        ));
      }

      return synthesizedTasks;
    } catch (e) {
      debugPrint('LocalAiLearnerService synthesis error: $e');
      return _generateDefaultFallbackRoutines();
    }
  }

  List<Map<String, dynamic>> _fallbackTemplate() {
    return [
      {
        'title': 'Morning Prep & Focus',
        'category': 'Study',
        'startHour': 8,
        'startMinute': 0,
        'durationMinutes': 60,
        'daysOfWeek': [1, 2, 3, 4, 5, 6, 7],
      },
      {
        'title': 'Core Activity Session',
        'category': 'Work',
        'startHour': 9,
        'startMinute': 30,
        'durationMinutes': 180,
        'daysOfWeek': [1, 2, 3, 4, 5, 6],
      },
      {
        'title': 'Lunch & Health Break',
        'category': 'Health',
        'startHour': 13,
        'startMinute': 0,
        'durationMinutes': 60,
        'daysOfWeek': [1, 2, 3, 4, 5, 6, 7],
      },
      {
        'title': 'Evening Skill Practice',
        'category': 'Personal',
        'startHour': 16,
        'startMinute': 0,
        'durationMinutes': 120,
        'daysOfWeek': [1, 2, 3, 4, 5, 6, 7],
      },
    ];
  }

  List<RoutineTask> _generateDefaultFallbackRoutines() {
    final now = DateTime.now();
    return _fallbackTemplate().map((map) {
      return RoutineTask(
        id: '${DateTime.now().microsecondsSinceEpoch}_fb',
        title: map['title'] as String,
        category: map['category'] as String,
        startTime: DateTime(
            now.year, now.month, now.day, map['startHour'] as int, map['startMinute'] as int),
        durationMinutes: map['durationMinutes'] as int,
        type: TaskType.routine,
        isCompleted: false,
        updatedAt: DateTime.now().toUtc(),
        daysOfWeek: List<int>.from(map['daysOfWeek'] as List),
      );
    }).toList();
  }
}
