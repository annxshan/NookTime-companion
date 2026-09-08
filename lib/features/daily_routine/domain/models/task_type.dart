/// Distinguishes between recurring daily routines and one-time reminders.
enum TaskType {
  /// Local-only daily recurring routine task.
  routine,

  /// One-time scheduled reminder synced with Google Calendar.
  reminder,
}

extension TaskTypeX on TaskType {
  String toSqlValue() {
    switch (this) {
      case TaskType.routine:
        return 'routine';
      case TaskType.reminder:
        return 'reminder';
    }
  }

  static TaskType fromSqlValue(String? value) {
    if (value == 'reminder') {
      return TaskType.reminder;
    }
    return TaskType.routine;
  }
}
