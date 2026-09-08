import 'package:equatable/equatable.dart';

/// Represents actual time logged for a specific task or routine activity.
///
/// Used for habit tracking, productive time calculations, and analytics charts.
class TimeLog extends Equatable {
  /// Unique identifier (UUID string or database auto-id).
  final String id;

  /// Foreign key referencing the associated [RoutineTask.id].
  final String taskId;

  /// Timestamp when the time logging entry occurred.
  final DateTime timestamp;

  /// Actual duration spent in minutes.
  final int durationSpentMinutes;

  const TimeLog({
    required this.id,
    required this.taskId,
    required this.timestamp,
    required this.durationSpentMinutes,
  });

  /// Serialise to a [Map] suitable for SQLite insertion.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task_id': taskId,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'duration_spent_minutes': durationSpentMinutes,
    };
  }

  /// Deserialise from a SQLite row [Map].
  factory TimeLog.fromMap(Map<String, dynamic> map) {
    return TimeLog(
      id: map['id'] as String,
      taskId: map['task_id'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      durationSpentMinutes: map['duration_spent_minutes'] as int,
    );
  }

  /// Returns a copy of this [TimeLog] with the given fields replaced.
  TimeLog copyWith({
    String? id,
    String? taskId,
    DateTime? timestamp,
    int? durationSpentMinutes,
  }) {
    return TimeLog(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      timestamp: timestamp ?? this.timestamp,
      durationSpentMinutes: durationSpentMinutes ?? this.durationSpentMinutes,
    );
  }

  @override
  List<Object?> get props => [
        id,
        taskId,
        timestamp,
        durationSpentMinutes,
      ];

  @override
  String toString() =>
      'TimeLog(id: $id, taskId: $taskId, timestamp: $timestamp, durationSpentMinutes: ${durationSpentMinutes}m)';
}
