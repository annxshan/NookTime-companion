import 'package:flutter/material.dart';
import '../../daily_routine/domain/models/routine_task.dart';

/// An on-device, deterministic schedule generation engine that parses user goals
/// and natural language inputs to produce optimized, conflict-free daily schedules.
class LocalScheduleEngine {
  /// Pre-optimized goal archetype keys.
  static const String archetypeExamPrep = 'exam_prep';
  static const String archetypeHealthyLifestyle = 'healthy_lifestyle';
  static const String archetypeDeepWork = 'deep_work';

  /// Map of pre-optimized goal archetypes to their default task templates.
  static final Map<String, List<Map<String, dynamic>>> _archetypes = {
    archetypeExamPrep: [
      {
        'title': 'Morning Prep & Quick Revision',
        'category': 'Study',
        'startHour': 8,
        'startMinute': 0,
        'durationMinutes': 45,
      },
      {
        'title': 'Deep Focus Study Session',
        'category': 'Study',
        'startHour': 9,
        'startMinute': 30,
        'durationMinutes': 180,
      },
      {
        'title': 'Lunch & Rest',
        'category': 'Health',
        'startHour': 13,
        'startMinute': 0,
        'durationMinutes': 60,
      },
      {
        'title': 'Problem Solving & Practice',
        'category': 'Study',
        'startHour': 15,
        'startMinute': 0,
        'durationMinutes': 150,
      },
      {
        'title': 'Review & Summary',
        'category': 'Study',
        'startHour': 19,
        'startMinute': 0,
        'durationMinutes': 90,
      },
      {
        'title': 'Evening Wind Down',
        'category': 'Personal',
        'startHour': 22,
        'startMinute': 30,
        'durationMinutes': 30,
      },
    ],
    archetypeHealthyLifestyle: [
      {
        'title': 'Morning Exercise & Hydration',
        'category': 'Health',
        'startHour': 7,
        'startMinute': 0,
        'durationMinutes': 45,
      },
      {
        'title': 'Core Focus Work',
        'category': 'Work',
        'startHour': 9,
        'startMinute': 0,
        'durationMinutes': 240,
      },
      {
        'title': 'Mindful Lunch',
        'category': 'Health',
        'startHour': 13,
        'startMinute': 0,
        'durationMinutes': 60,
      },
      {
        'title': 'Quick Walk / Stretch',
        'category': 'Health',
        'startHour': 15,
        'startMinute': 30,
        'durationMinutes': 30,
      },
      {
        'title': 'Personal Projects / Learning',
        'category': 'Personal',
        'startHour': 17,
        'startMinute': 0,
        'durationMinutes': 120,
      },
      {
        'title': 'Night Relaxation',
        'category': 'Health',
        'startHour': 22,
        'startMinute': 0,
        'durationMinutes': 30,
      },
    ],
    archetypeDeepWork: [
      {
        'title': 'High-Leverage Tasks',
        'category': 'Work',
        'startHour': 9,
        'startMinute': 0,
        'durationMinutes': 180,
      },
      {
        'title': 'Focused Execution',
        'category': 'Work',
        'startHour': 14,
        'startMinute': 0,
        'durationMinutes': 180,
      },
      {
        'title': 'Inbox & Planning',
        'category': 'Work',
        'startHour': 18,
        'startMinute': 0,
        'durationMinutes': 60,
      },
    ],
  };

  /// Regex for explicit time ranges like "8:30am to 1pm", "8:30 AM - 1:00 PM", "9am - 12pm", or "08:30-13:00".
  static final RegExp _timeRangeRegex = RegExp(
    r'(\d{1,2}(?::\d{2})?\s*(?:am|pm)?)\s*(?:to|-|until)\s*(\d{1,2}(?::\d{2})?\s*(?:am|pm)?)',
    caseSensitive: false,
  );

  /// Returns a list of tasks for a pre-optimized goal archetype template.
  List<Map<String, dynamic>> getTemplateSchedule(String key) =>
      getArchetypeSchedule(key);

  /// Returns a list of tasks for a pre-optimized goal archetype.
  List<Map<String, dynamic>> getArchetypeSchedule(String key) {
    final list = _archetypes[key];
    if (list == null) return [];
    return list.map((task) => Map<String, dynamic>.from(task)).toList();
  }

  /// Dedicated robust time parser converting raw time strings (e.g. "8:30am", "8:30 AM", "1pm", "1:00 PM")
  /// into exact 24-hour [TimeOfDay] instances.
  TimeOfDay parseTimeString(String rawTime) {
    final clean = rawTime.trim().toLowerCase();
    final isPm = clean.contains('pm');
    final isAm = clean.contains('am');

    final numReg = RegExp(r'(\d{1,2})(?::(\d{2}))?');
    final match = numReg.firstMatch(clean);
    if (match == null) return const TimeOfDay(hour: 8, minute: 0);

    int hour = int.parse(match.group(1)!);
    int minute = match.group(2) != null ? int.parse(match.group(2)!) : 0;

    if (isPm) {
      if (hour < 12) hour += 12;
    } else if (isAm) {
      if (hour == 12) hour = 0;
    } else {
      // 24-hour military format heuristic
      if (hour >= 24) hour = hour % 24;
    }

    return TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
  }

  /// Parses a natural language user prompt or goal archetype keyword,
  /// extracts tasks, merges foundation slots, and resolves schedule conflicts.
  List<Map<String, dynamic>> parseCustomPrompt(
    String input, {
    List<RoutineTask>? existingTasks,
  }) {
    final cleanInput = input.trim();
    if (cleanInput.isEmpty) return [];

    final matchedArchetype = _detectArchetype(cleanInput);
    if (matchedArchetype != null) {
      return resolveConflicts(getArchetypeSchedule(matchedArchetype),
          existingTasks: existingTasks);
    }

    final targeted = _extractTargetedTask(cleanInput);
    if (targeted != null) {
      return resolveConflicts(targeted, existingTasks: existingTasks);
    }

    // Step 1: Extract explicit time commitments & fixed blocks (e.g. college 8:30am to 1pm)
    final explicitBlocks = _extractExplicitTimeBlocks(cleanInput);

    // Step 2: Build a full-day healthy, structured schedule skeleton around fixed commitments
    final synthesizedTasks = _synthesizeSchedule(cleanInput, explicitBlocks);

    // Step 3: Perform conflict resolution against existing tasks and among generated slots
    return resolveConflicts(synthesizedTasks, existingTasks: existingTasks);
  }

  /// Extracts targeted single/few tasks if prompt specifies individual goals (e.g. "learn Japanese on weekends for 2 hours").
  List<Map<String, dynamic>>? _extractTargetedTask(String input) {
    final lower = input.toLowerCase();

    // If input contains explicit fixed time blocks (e.g. "college from 8:30am to 1pm"), run full schedule builder around fixed commitments
    if (_extractExplicitTimeBlocks(input).isNotEmpty) return null;

    // Check if input requests a full routine or archetype template
    final isFullRoutineRequest = lower.contains('full day') ||
        lower.contains('whole day') ||
        lower.contains('full routine') ||
        lower.contains('daily routine') ||
        lower.contains('exam prep') ||
        lower.contains('healthy lifestyle') ||
        lower.contains('deep work');

    if (isFullRoutineRequest) return null;

    // Must describe a specific activity or commitment
    final isSpecificActivity = lower.contains('learn') ||
        lower.contains('japanese') ||
        lower.contains('study') ||
        lower.contains('workout') ||
        lower.contains('gym') ||
        lower.contains('exercise') ||
        lower.contains('practice') ||
        lower.contains('project') ||
        lower.contains('read') ||
        lower.contains('for ') ||
        lower.contains('on ');

    if (!isSpecificActivity) return null;

    // Parse duration
    final durationMatch = RegExp(r'(\d+)\s*(hour|hr|minute|min)').firstMatch(lower);
    int durationMinutes = 60;
    if (durationMatch != null) {
      final val = int.tryParse(durationMatch.group(1)!) ?? 1;
      final unit = durationMatch.group(2)!;
      if (unit.startsWith('h')) {
        durationMinutes = val * 60;
      } else {
        durationMinutes = val;
      }
    }

    // Parse days of week
    List<int> daysOfWeek = const [1, 2, 3, 4, 5, 6, 7];
    if (lower.contains('weekend')) {
      daysOfWeek = const [6, 7];
    } else if (lower.contains('weekday')) {
      daysOfWeek = const [1, 2, 3, 4, 5];
    } else if (lower.contains('saturday')) {
      daysOfWeek = const [6];
    } else if (lower.contains('sunday')) {
      daysOfWeek = const [7];
    }

    String title = 'Personal Learning & Study';
    String category = 'Study';

    if (lower.contains('japanese') || lower.contains('language')) {
      title = 'Japanese Language Practice';
      category = 'Study';
    } else if (lower.contains('workout') || lower.contains('gym') || lower.contains('exercise')) {
      title = 'Fitness & Workout Session';
      category = 'Health';
    } else if (lower.contains('work') || lower.contains('project')) {
      title = 'Core Project Work';
      category = 'Work';
    } else if (lower.contains('study') || lower.contains('read')) {
      title = 'Focus Study Session';
      category = 'Study';
    }

    int startHour = 14; // Default to 2:00 PM daytime slot
    if (lower.contains('morning')) startHour = 9;
    if (lower.contains('evening')) startHour = 18;

    return [
      {
        'title': title,
        'category': category,
        'startHour': startHour,
        'startMinute': 0,
        'durationMinutes': durationMinutes,
        'daysOfWeek': daysOfWeek,
      }
    ];
  }

  /// Detects whether input is an archetype key or exact preset name.
  String? _detectArchetype(String input) {
    final lower = input.toLowerCase().trim();
    if (lower == archetypeExamPrep ||
        lower == 'exam prep' ||
        lower == 'exam preparation' ||
        lower.contains('🎯 exam preparation')) {
      return archetypeExamPrep;
    }
    if (lower == archetypeHealthyLifestyle ||
        lower == 'healthy lifestyle' ||
        lower == 'healthy & balanced' ||
        lower.contains('🥗 healthy & balanced')) {
      return archetypeHealthyLifestyle;
    }
    if (lower == archetypeDeepWork ||
        lower == 'deep work' ||
        lower == 'deep work & focus' ||
        lower.contains('⚡ deep work & focus')) {
      return archetypeDeepWork;
    }
    return null;
  }

  /// Extracts explicit time range commitments from text (e.g., "college from 8:30am to 1pm").
  List<Map<String, dynamic>> _extractExplicitTimeBlocks(String input) {
    final List<Map<String, dynamic>> blocks = [];
    final matches = _timeRangeRegex.allMatches(input);

    for (final match in matches) {
      final startStr = match.group(1);
      final endStr = match.group(2);
      if (startStr == null || endStr == null) continue;

      final startTod = parseTimeString(startStr);
      var endTod = parseTimeString(endStr);

      int startMins = startTod.hour * 60 + startTod.minute;
      int endMins = endTod.hour * 60 + endTod.minute;

      // Handle cases where end time is 1pm (13:00) and start time is 8:30am (08:30)
      if (endMins <= startMins) {
        if (!endStr.toLowerCase().contains('am') &&
            !endStr.toLowerCase().contains('pm')) {
          // If end string has no explicit am/pm and is numerically smaller, add 12 hours
          if ((endTod.hour + 12) * 60 > startMins) {
            endTod = TimeOfDay(hour: endTod.hour + 12, minute: endTod.minute);
            endMins = endTod.hour * 60 + endTod.minute;
          }
        }
      }

      if (endMins <= startMins) continue;

      final duration = endMins - startMins;

      // Extract context string around the match
      final matchIndex = match.start;
      final substringBefore = input.substring(0, matchIndex).toLowerCase();

      String title = 'College / Classes';
      String category = 'Study';

      if (substringBefore.contains('college') ||
          substringBefore.contains('class') ||
          substringBefore.contains('lecture') ||
          substringBefore.contains('school')) {
        title = 'College / Classes';
        category = 'Study';
      } else if (substringBefore.contains('work') ||
          substringBefore.contains('office')) {
        title = 'Core Focus Work';
        category = 'Work';
      } else if (substringBefore.contains('study') ||
          substringBefore.contains('exam')) {
        title = 'Focus Study Session';
        category = 'Study';
      } else {
        final lowerInput = input.toLowerCase();
        if (lowerInput.contains('college') || lowerInput.contains('class')) {
          title = 'College / Classes';
          category = 'Study';
        }
      }

      blocks.add({
        'title': title,
        'category': category,
        'startHour': startTod.hour,
        'startMinute': startTod.minute,
        'durationMinutes': duration,
        'isFixed': true,
      });
    }

    return blocks;
  }

  /// Synthesizes a structured daily schedule based on input keywords and fixed blocks.
  List<Map<String, dynamic>> _synthesizeSchedule(
    String input,
    List<Map<String, dynamic>> explicitBlocks,
  ) {
    final lower = input.toLowerCase();

    final hasCollege = lower.contains('college') ||
        lower.contains('class') ||
        lower.contains('lecture') ||
        lower.contains('school');
    final hasFlutter = lower.contains('flutter');
    final hasCoding = lower.contains('code') ||
        lower.contains('coding') ||
        lower.contains('dev');
    final hasStudy = lower.contains('study') ||
        lower.contains('exam') ||
        lower.contains('test');
    final hasWorkout = lower.contains('workout') ||
        lower.contains('gym') ||
        lower.contains('exercise') ||
        lower.contains('walk');

    final List<Map<String, dynamic>> schedule = [];

    // 1. Morning Slot (07:00 AM - 08:00 AM)
    schedule.add({
      'title': 'Morning Refresh & Breakfast',
      'category': 'Health',
      'startHour': 7,
      'startMinute': 0,
      'durationMinutes': 60,
    });

    // 2. Fixed Commitment Block (08:30 AM - 01:00 PM)
    if (explicitBlocks.isNotEmpty) {
      schedule.addAll(explicitBlocks);
    } else if (hasCollege) {
      schedule.add({
        'title': 'College / Classes',
        'category': 'Study',
        'startHour': 8,
        'startMinute': 30,
        'durationMinutes': 270,
      });
    } else if (hasCoding || hasStudy) {
      schedule.add({
        'title': hasCoding ? 'Software Development' : 'Focus Study Session',
        'category': hasCoding ? 'Work' : 'Study',
        'startHour': 9,
        'startMinute': 0,
        'durationMinutes': 180,
      });
    }

    // 3. Post-Commitment Lunch Slot (01:00 PM - 02:00 PM)
    schedule.add({
      'title': 'Healthy Lunch & Rest',
      'category': 'Health',
      'startHour': 13,
      'startMinute': 0,
      'durationMinutes': 60,
    });

    // 4. Skill / Learning Slot (03:30 PM - 05:30 PM)
    if (hasFlutter) {
      schedule.add({
        'title': 'Flutter App Development',
        'category': 'Study',
        'startHour': 15,
        'startMinute': 30,
        'durationMinutes': 120,
      });
    } else if (hasCoding) {
      schedule.add({
        'title': 'Software Development',
        'category': 'Work',
        'startHour': 15,
        'startMinute': 30,
        'durationMinutes': 120,
      });
    } else if (hasStudy) {
      schedule.add({
        'title': 'Focus Study Session',
        'category': 'Study',
        'startHour': 15,
        'startMinute': 30,
        'durationMinutes': 120,
      });
    } else {
      schedule.add({
        'title': 'Personal Projects / Learning',
        'category': 'Personal',
        'startHour': 15,
        'startMinute': 30,
        'durationMinutes': 120,
      });
    }

    // 5. Evening Fitness Slot (06:00 PM - 07:00 PM)
    schedule.add({
      'title': hasWorkout ? 'Evening Workout & Walk' : 'Evening Walk & Stretch',
      'category': 'Health',
      'startHour': 18,
      'startMinute': 0,
      'durationMinutes': 60,
    });

    // 6. Dinner & Wind Down Slot (08:30 PM - 10:00 PM)
    schedule.add({
      'title': 'Dinner & Relaxation',
      'category': 'Health',
      'startHour': 20,
      'startMinute': 30,
      'durationMinutes': 90,
      'daysOfWeek': const [1, 2, 3, 4, 5, 6, 7],
    });

    // 7. Sunday / Weekend Deep Work & Project Revision (Day 7)
    if (lower.contains('sunday') || lower.contains('weekend') || lower.contains('project') || lower.contains('revision')) {
      schedule.add({
        'title': 'Sunday Deep Study & Project Revision',
        'category': 'Study',
        'startHour': 10,
        'startMinute': 0,
        'durationMinutes': 180,
        'daysOfWeek': const [7],
      });
    }

    // Sanitize titles
    for (final task in schedule) {
      task['title'] = _sanitizeTitle(task['title'] as String, task['category'] as String);
    }

    // Sort schedule strictly chronologically by start time
    schedule.sort((a, b) {
      final aMins = (a['startHour'] as int) * 60 + (a['startMinute'] as int);
      final bMins = (b['startHour'] as int) * 60 + (b['startMinute'] as int);
      return aMins.compareTo(bMins);
    });

    return schedule;
  }

  /// Sanitizes raw titles to make them clean, concise, title-cased, and professional.
  String _sanitizeTitle(String title, String category) {
    String cleaned = title
        .replaceAll(
          RegExp(
            r'\b(i|have|want|need|to|for|a|an|the|my|some|add|keep|create|design|plan|schedule|hours?|mins?|minutes?|hrs?|make|get|routine|daily)\b',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (cleaned.length < 3) {
      switch (category) {
        case 'Study':
          return 'Focus Study Session';
        case 'Health':
          return 'Health & Fitness';
        case 'Work':
          return 'Core Work Session';
        default:
          return 'Personal Activity';
      }
    }

    // Capitalize each word cleanly
    final words = cleaned.split(' ');
    final capitalized = words.map((w) {
      if (w.isEmpty) return '';
      if (w.contains('/')) {
        return w.split('/').map((part) {
          if (part.isEmpty) return '';
          return part[0].toUpperCase() + (part.length > 1 ? part.substring(1) : '');
        }).join(' / ');
      }
      return w[0].toUpperCase() + (w.length > 1 ? w.substring(1) : '');
    }).join(' ');

    return capitalized;
  }

  /// Resolves overlaps between tasks and against existing scheduled routines.
  List<Map<String, dynamic>> resolveConflicts(
    List<Map<String, dynamic>> inputTasks, {
    List<RoutineTask>? existingTasks,
  }) {
    if (inputTasks.isEmpty) return [];

    final List<_Interval> occupied = [];

    // Add existing scheduled tasks to occupied intervals
    if (existingTasks != null) {
      for (final et in existingTasks) {
        final startMins = et.startTime.hour * 60 + et.startTime.minute;
        final endMins = startMins + et.durationMinutes;
        occupied.add(_Interval(startMins, endMins));
      }
    }

    final List<Map<String, dynamic>> resolvedTasks = [];

    // Sort input tasks strictly chronologically by initial start time
    final sortedInput = inputTasks.map((t) => Map<String, dynamic>.from(t)).toList()
      ..sort((a, b) {
        final aMins = (a['startHour'] as int) * 60 + (a['startMinute'] as int);
        final bMins = (b['startHour'] as int) * 60 + (b['startMinute'] as int);
        return aMins.compareTo(bMins);
      });

    for (final task in sortedInput) {
      int startMins = (task['startHour'] as int) * 60 + (task['startMinute'] as int);
      final duration = task['durationMinutes'] as int;
      final titleLower = (task['title'] as String? ?? '').toLowerCase();

      // Check if task is explicitly requested for overnight/night hours
      final isExplicitOvernight = titleLower.contains('overnight') ||
          titleLower.contains('night shift') ||
          titleLower.contains('late night') ||
          titleLower.contains('1am') ||
          titleLower.contains('2am') ||
          titleLower.contains('3am') ||
          titleLower.contains('4am');

      // Sanity check: College / Classes / Work / General tasks MUST start in daytime awake hours
      if (!isExplicitOvernight) {
        if (startMins < 360) {
          startMins = 360; // Clamp early morning to 06:00 AM
        } else if (startMins >= 1350) {
          startMins = 840; // Shift late night (>= 10:30 PM) to 02:00 PM daytime
        }
      }

      // Find first non-overlapping time slot
      bool hasConflict = true;
      while (hasConflict) {
        hasConflict = false;
        final endMins = startMins + duration;

        for (final interval in occupied) {
          if (startMins < interval.end && endMins > interval.start) {
            // Overlap detected: shift start time to end of overlapping interval
            startMins = interval.end;
            hasConflict = true;
            break;
          }
        }

        // Clamp to end of daytime (10:30 PM = 1350 mins) if shifting pushed task into overnight hours
        if (!isExplicitOvernight && startMins >= 1350) {
          startMins = 840; // Reset to 2:00 PM afternoon slot if day is full
          break;
        }
      }

      final finalStartHour = (startMins ~/ 60).clamp(0, 23);
      final finalStartMinute = (startMins % 60).clamp(0, 59);

      task['startHour'] = finalStartHour;
      task['startMinute'] = finalStartMinute;
      if (!task.containsKey('daysOfWeek')) {
        final titleLower = (task['title'] as String? ?? '').toLowerCase();
        final isCollegeOrWork = titleLower.contains('college') ||
            titleLower.contains('class') ||
            titleLower.contains('school') ||
            titleLower.contains('work');
        task['daysOfWeek'] = isCollegeOrWork ? const [1, 2, 3, 4, 5] : const [1, 2, 3, 4, 5, 6, 7];
      }

      occupied.add(_Interval(startMins, startMins + duration));

      resolvedTasks.add(task);
    }

    // Ensure final list is ordered strictly chronologically
    resolvedTasks.sort((a, b) {
      final aMins = (a['startHour'] as int) * 60 + (a['startMinute'] as int);
      final bMins = (b['startHour'] as int) * 60 + (b['startMinute'] as int);
      return aMins.compareTo(bMins);
    });

    return resolvedTasks;
  }
}

class _Interval {
  final int start;
  final int end;

  _Interval(this.start, this.end);
}
