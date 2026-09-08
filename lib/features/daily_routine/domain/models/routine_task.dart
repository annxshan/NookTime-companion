import 'package:equatable/equatable.dart';
import 'task_type.dart';

/// Represents a task (routine or reminder) in Nooktime.
///
/// Routines are local-only daily recurring habits that can run on specific days of the week.
/// Reminders are scheduled date/time events that optionally push single events to Google Calendar.
class RoutineTask extends Equatable {
  /// Unique identifier (UUID v4 string).
  final String id;

  /// Human-readable title of the task.
  final String title;

  /// Categorisation label (e.g. "Work", "Health", "Personal", "Study").
  final String category;

  /// Scheduled start time / date for this task.
  final DateTime startTime;

  /// Planned duration in minutes.
  final int durationMinutes;

  /// Whether the task has been marked complete for the day/instance.
  /// For routines, prefer checking [isCompletedToday] which accounts for the
  /// midnight auto-reset based on [lastCompletedDate].
  final bool isCompleted;

  /// Task type: routine or reminder.
  final TaskType type;

  /// Optional Google Calendar event ID for single-event sync (reminders only).
  final String? googleEventId;

  /// Timestamp of the last modification — used for sync conflict resolution.
  final DateTime updatedAt;

  /// The local calendar date (YYYY-MM-DD) on which this task was last marked
  /// complete. Null if never completed. Used for midnight auto-reset logic.
  final String? lastCompletedDate;

  /// Days of week when this routine task is active (1 = Monday, ..., 7 = Sunday).
  /// Defaults to all 7 days ([1, 2, 3, 4, 5, 6, 7]).
  final List<int> daysOfWeek;

  const RoutineTask({
    required this.id,
    required this.title,
    required this.category,
    required this.startTime,
    required this.durationMinutes,
    this.isCompleted = false,
    this.type = TaskType.routine,
    this.googleEventId,
    required this.updatedAt,
    this.lastCompletedDate,
    this.daysOfWeek = const [1, 2, 3, 4, 5, 6, 7],
  });

  bool get isReminder => type == TaskType.reminder;
  bool get isRoutine => type == TaskType.routine;

  /// Returns whether this routine is active on the given weekday (1 = Mon, ..., 7 = Sun).
  bool isScheduledForDay(int weekday) {
    if (isReminder) return true;
    return daysOfWeek.contains(weekday);
  }

  /// Returns today's local date as a YYYY-MM-DD string.
  static String get todayDateString {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// True if this routine task has been completed today (i.e. [lastCompletedDate]
  /// matches today's local date). This is the midnight-reset-aware completion
  /// state. Reminders simply use [isCompleted] directly.
  bool get isCompletedToday {
    if (isReminder) return isCompleted;
    return lastCompletedDate == RoutineTask.todayDateString;
  }

  /// Serialise to a [Map] suitable for SQLite insertion.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'start_time': startTime.toUtc().toIso8601String(),
      'duration_minutes': durationMinutes,
      'is_completed': isCompleted ? 1 : 0,
      'task_type': type.toSqlValue(),
      'google_event_id': googleEventId,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'last_completed_date': lastCompletedDate,
      'days_of_week': daysOfWeek.isNotEmpty ? daysOfWeek.join(',') : '1,2,3,4,5,6,7',
    };
  }

  /// Deserialise from a SQLite row [Map].
  factory RoutineTask.fromMap(Map<String, dynamic> map) {
    final parsedDays = map['days_of_week'] != null
        ? (map['days_of_week'] as String)
            .split(',')
            .where((s) => s.isNotEmpty)
            .map((e) => int.tryParse(e.trim()) ?? 1)
            .toList()
        : const [1, 2, 3, 4, 5, 6, 7];

    return RoutineTask(
      id: map['id'] as String,
      title: map['title'] as String,
      category: map['category'] as String,
      startTime: DateTime.parse(map['start_time'] as String).toLocal(),
      durationMinutes: (map['duration_minutes'] as int?) ?? 30,
      isCompleted: (map['is_completed'] as int) == 1,
      type: TaskTypeX.fromSqlValue(map['task_type'] as String?),
      googleEventId: map['google_event_id'] as String?,
      updatedAt: DateTime.parse(map['updated_at'] as String).toLocal(),
      lastCompletedDate: map['last_completed_date'] as String?,
      daysOfWeek: parsedDays.isNotEmpty ? parsedDays : const [1, 2, 3, 4, 5, 6, 7],
    );
  }

  /// Returns a copy of this task with the specified fields replaced.
  RoutineTask copyWith({
    String? id,
    String? title,
    String? category,
    DateTime? startTime,
    int? durationMinutes,
    bool? isCompleted,
    TaskType? type,
    String? Function()? googleEventId,
    DateTime? updatedAt,
    String? Function()? lastCompletedDate,
    List<int>? daysOfWeek,
  }) {
    return RoutineTask(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      startTime: startTime ?? this.startTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      isCompleted: isCompleted ?? this.isCompleted,
      type: type ?? this.type,
      googleEventId:
          googleEventId != null ? googleEventId() : this.googleEventId,
      updatedAt: updatedAt ?? this.updatedAt,
      lastCompletedDate: lastCompletedDate != null
          ? lastCompletedDate()
          : this.lastCompletedDate,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        category,
        startTime,
        durationMinutes,
        isCompleted,
        type,
        googleEventId,
        updatedAt,
        lastCompletedDate,
        daysOfWeek,
      ];

  @override
  String toString() =>
      'RoutineTask(id: $id, title: $title, category: $category, '
      'startTime: $startTime, durationMinutes: $durationMinutes, '
      'isCompleted: $isCompleted, type: $type, googleEventId: $googleEventId, '
      'updatedAt: $updatedAt, lastCompletedDate: $lastCompletedDate, daysOfWeek: $daysOfWeek)';
}
