import 'package:sqflite/sqflite.dart';

import '../../../core/services/database_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/notification_settings_controller.dart';
import '../../calendar_sync/services/auth_service.dart';
import '../../calendar_sync/services/google_calendar_service.dart';
import '../../sync/services/cloud_sync_service.dart';
import '../domain/models/routine_task.dart';
import '../domain/models/task_type.dart';
import '../domain/models/time_log.dart';

/// Repository managing local routines, one-time reminders, notifications,
/// Google Calendar integration, and Cloud Firestore dual-sync.
class RoutineRepository {
  final DatabaseService _databaseService;
  final NotificationService _notificationService;
  final GoogleCalendarService _googleCalendarService;
  final AuthService _authService;
  final CloudSyncService? _cloudSyncService;

  RoutineRepository({
    required DatabaseService databaseService,
    required NotificationService notificationService,
    required GoogleCalendarService googleCalendarService,
    required AuthService authService,
    CloudSyncService? cloudSyncService,
  })  : _databaseService = databaseService,
        _notificationService = notificationService,
        _googleCalendarService = googleCalendarService,
        _authService = authService,
        _cloudSyncService = cloudSyncService;

  /// Creates a local-only daily recurring routine task and dual-writes to Cloud Firestore.
  Future<RoutineTask> createRoutine({
    required String title,
    required String category,
    required DateTime startTime,
    required int durationMinutes,
    List<int> daysOfWeek = const [1, 2, 3, 4, 5, 6, 7],
  }) async {
    final now = DateTime.now().toUtc();
    final taskId = DateTime.now().millisecondsSinceEpoch.toString();

    final task = RoutineTask(
      id: taskId,
      title: title,
      category: category,
      startTime: startTime,
      durationMinutes: durationMinutes,
      type: TaskType.routine,
      isCompleted: false,
      updatedAt: now,
      daysOfWeek: daysOfWeek,
    );

    // 1. Insert into local SQLite database
    await _databaseService.insertTask(task);

    // 2. Schedule daily recurring on-device push alarms if routine notifications enabled
    await NotificationService.cancelRoutineTaskNotifications(task.id);
    if (NotificationSettingsController.instance.routineNotificationsEnabled) {
      for (final day in task.daysOfWeek) {
        final notifId = NotificationService.getNotificationId(task.id, day);
        await _notificationService.scheduleWeeklyReminder(
          id: notifId,
          title: 'Routine: ${task.title}',
          body: 'Time for your $category routine (${task.durationMinutes} mins)',
          hour: startTime.toLocal().hour,
          minute: startTime.toLocal().minute,
          dayOfWeek: day,
        );
      }
    }

    // 3. Dual-write to Cloud Firestore (non-blocking)
    try {
      await _cloudSyncService?.uploadTask(task);
    } catch (_) {}

    return task;
  }

  /// Creates a one-time scheduled reminder for a specific date and time and dual-writes to Cloud Firestore.
  Future<RoutineTask> createReminder({
    required String title,
    required String category,
    required DateTime dateTime,
    int durationMinutes = 30,
  }) async {
    final now = DateTime.now().toUtc();
    final taskId = DateTime.now().millisecondsSinceEpoch.toString();

    var reminder = RoutineTask(
      id: taskId,
      title: title,
      category: category,
      startTime: dateTime,
      durationMinutes: durationMinutes,
      type: TaskType.reminder,
      isCompleted: false,
      updatedAt: now,
    );

    // 1. Insert into local SQLite database
    await _databaseService.insertTask(reminder);

    // 2. Schedule exact local notification for specific date & time if reminder notifications enabled
    await NotificationService.cancelSingleNotification(reminder.id);
    if (NotificationSettingsController.instance.reminderNotificationsEnabled) {
      final notifId = NotificationService.getNotificationId(reminder.id);
      await _notificationService.scheduleExactReminder(
        id: notifId,
        title: 'Reminder: ${reminder.title}',
        body: 'Scheduled for ${reminder.category}',
        scheduledDateTime: dateTime,
      );
    }

    // 3. Automatically sync with Google Calendar as a single event snapshot
    if (_authService.isSignedIn) {
      try {
        final endTime = dateTime.add(Duration(minutes: durationMinutes));
        final googleEventId = await _googleCalendarService.createSingleEvent(
          title: title,
          category: category,
          startTime: dateTime,
          endTime: endTime,
        );

        if (googleEventId != null) {
          reminder = reminder.copyWith(
            googleEventId: () => googleEventId,
            updatedAt: DateTime.now().toUtc(),
          );
          await _databaseService.updateTask(reminder);
        }
      } catch (_) {
        // Fallback: local reminder remains intact if Google API fails
      }
    }

    // 4. Dual-write to Cloud Firestore (non-blocking)
    try {
      await _cloudSyncService?.uploadTask(reminder);
    } catch (_) {}

    return reminder;
  }

  /// Direct method to insert a task and dual-write to Cloud Firestore.
  Future<void> addTask(RoutineTask task) async {
    await _databaseService.insertTask(task);
    try {
      await _cloudSyncService?.uploadTask(task);
    } catch (_) {}
  }

  /// Applies a list of AI-generated routine task maps [rawAiTasks] into SQLite
  /// and schedules daily local notifications for each.
  Future<List<RoutineTask>> applyAiGeneratedRoutine({
    required List<Map<String, dynamic>> rawAiTasks,
    bool overwriteExisting = false,
  }) async {
    if (overwriteExisting) {
      final currentRoutines = await _databaseService.getTasksByType(TaskType.routine);
      for (final routine in currentRoutines) {
        await NotificationService.cancelRoutineTaskNotifications(routine.id);
        await NotificationService.cancelSingleNotification(routine.id);
        await _databaseService.deleteTask(routine.id);
        try {
          await _cloudSyncService?.deleteTask(routine.id);
        } catch (_) {}
      }
    }

    final List<RoutineTask> createdTasks = [];
    final now = DateTime.now();

    for (int i = 0; i < rawAiTasks.length; i++) {
      final raw = rawAiTasks[i];

      final title = (raw['title'] as String?)?.trim() ?? 'AI Task';
      final category = (raw['category'] as String?)?.trim() ?? 'Personal';
      final startHour = (raw['startHour'] as num?)?.toInt() ?? 8;
      final startMinute = (raw['startMinute'] as num?)?.toInt() ?? 0;
      final durationMinutes = (raw['durationMinutes'] as num?)?.toInt() ?? 30;

      final rawDays = raw['daysOfWeek'] as List<dynamic>?;
      final daysOfWeek = (rawDays != null && rawDays.isNotEmpty)
          ? rawDays
              .map((e) => int.tryParse(e.toString()) ?? 1)
              .where((d) => d >= 1 && d <= 7)
              .toList()
          : const <int>[1, 2, 3, 4, 5, 6, 7];

      final startTime = DateTime(
        now.year,
        now.month,
        now.day,
        startHour,
        startMinute,
      );

      final taskId = '${DateTime.now().microsecondsSinceEpoch}_$i';

      final task = RoutineTask(
        id: taskId,
        title: title,
        category: category,
        startTime: startTime,
        durationMinutes: durationMinutes,
        type: TaskType.routine,
        isCompleted: false,
        updatedAt: DateTime.now().toUtc(),
        daysOfWeek: daysOfWeek.isNotEmpty ? daysOfWeek : const <int>[1, 2, 3, 4, 5, 6, 7],
      );

      // 1. Insert into local SQLite database
      await _databaseService.insertTask(task);

      // 2. Schedule recurring daily local notification alarms if routine notifications enabled
      await NotificationService.cancelRoutineTaskNotifications(task.id);
      if (NotificationSettingsController.instance.routineNotificationsEnabled) {
        for (final day in task.daysOfWeek) {
          final notifId = NotificationService.getNotificationId(task.id, day);
          await _notificationService.scheduleWeeklyReminder(
            id: notifId,
            title: task.title,
            body: "It's time for ${task.title}!",
            hour: startHour,
            minute: startMinute,
            dayOfWeek: day,
          );
        }
      }

      createdTasks.add(task);
    }

    // 3. Batch upload all AI-generated tasks to Cloud Firestore (non-blocking)
    try {
      await _cloudSyncService?.uploadAllLocalTasks(createdTasks);
    } catch (_) {}

    return createdTasks;
  }

  /// Updates an existing routine or reminder and dual-writes to Cloud Firestore.
  Future<void> updateTask(RoutineTask task) async {
    final updatedTask = task.copyWith(
      updatedAt: DateTime.now().toUtc(),
    );

    await _databaseService.updateTask(updatedTask);

    // Cancel all existing pending system notifications prior to rescheduling upon edit
    await NotificationService.cancelSingleNotification(task.id);
    await NotificationService.cancelRoutineTaskNotifications(task.id);

    // Reschedule local notification based on type & user preferences
    if (task.isReminder) {
      if (NotificationSettingsController.instance.reminderNotificationsEnabled) {
        final notifId = NotificationService.getNotificationId(task.id);
        await _notificationService.scheduleExactReminder(
          id: notifId,
          title: 'Reminder: ${task.title}',
          body: 'Time for your ${task.category} reminder',
          scheduledDateTime: task.startTime,
        );
      }
    } else {
      if (NotificationSettingsController.instance.routineNotificationsEnabled) {
        for (final day in task.daysOfWeek) {
          final notifId = NotificationService.getNotificationId(task.id, day);
          await _notificationService.scheduleWeeklyReminder(
            id: notifId,
            title: 'Routine: ${task.title}',
            body: 'Time for your ${task.category} routine',
            hour: task.startTime.toLocal().hour,
            minute: task.startTime.toLocal().minute,
            dayOfWeek: day,
          );
        }
      }
    }

    // If reminder with Google Calendar event, update remote event
    if (task.isReminder && task.googleEventId != null && _authService.isSignedIn) {
      try {
        await _googleCalendarService.updateCalendarEvent(updatedTask);
      } catch (_) {}
    }

    // Dual-write to Cloud Firestore (non-blocking)
    try {
      await _cloudSyncService?.uploadTask(updatedTask);
    } catch (_) {}
  }

  /// Deletes a routine or reminder:
  /// 1. Cancels all pending system notifications.
  /// 2. Deletes record from local SQLite database.
  /// 3. Deletes remote event from Google Calendar (if reminder had googleEventId).
  /// 4. Deletes task document from Cloud Firestore.
  Future<void> deleteTask(RoutineTask task) async {
    // 1. Delete from local SQLite database immediately for zero UI latency
    await _databaseService.deleteTask(task.id);

    // 2. Cancel on-device local notifications (single & routine weekday instances)
    await NotificationService.cancelSingleNotification(task.id);
    await NotificationService.cancelRoutineTaskNotifications(task.id);

    // 3. Delete remote event from Google Calendar if present (non-blocking background)
    if (task.googleEventId != null && _authService.isSignedIn) {
      _googleCalendarService.deleteCalendarEvent(task.googleEventId).catchError((_) {});
    }

    // 4. Delete document from Cloud Firestore (non-blocking background)
    try {
      _cloudSyncService?.deleteTask(task.id);
    } catch (_) {}
  }

  /// Deletes a task by ID from SQLite and Cloud Firestore.
  Future<void> deleteTaskById(String taskId) async {
    await NotificationService.cancelSingleNotification(taskId);
    await NotificationService.cancelRoutineTaskNotifications(taskId);
    await _databaseService.deleteTask(taskId);
    try {
      await _cloudSyncService?.deleteTask(taskId);
    } catch (_) {}
  }

  /// Restores a deleted routine or reminder (Undo functionality):
  /// Re-inserts the task into SQLite database, reschedules notifications, and dual-writes to Cloud Firestore.
  Future<void> restoreTask(RoutineTask task) async {
    await _databaseService.insertTask(task);

    await NotificationService.cancelSingleNotification(task.id);
    await NotificationService.cancelRoutineTaskNotifications(task.id);

    if (task.isReminder) {
      if (NotificationSettingsController.instance.reminderNotificationsEnabled) {
        final notifId = NotificationService.getNotificationId(task.id);
        await _notificationService.scheduleExactReminder(
          id: notifId,
          title: 'Reminder: ${task.title}',
          body: 'Scheduled for ${task.category}',
          scheduledDateTime: task.startTime,
        );
      }
    } else {
      if (NotificationSettingsController.instance.routineNotificationsEnabled) {
        for (final day in task.daysOfWeek) {
          final notifId = NotificationService.getNotificationId(task.id, day);
          await _notificationService.scheduleWeeklyReminder(
            id: notifId,
            title: 'Routine: ${task.title}',
            body: 'Time for your ${task.category} routine (${task.durationMinutes} mins)',
            hour: task.startTime.toLocal().hour,
            minute: task.startTime.toLocal().minute,
            dayOfWeek: day,
          );
        }
      }
    }

    // Dual-write to Cloud Firestore (non-blocking)
    try {
      await _cloudSyncService?.uploadTask(task);
    } catch (_) {}
  }

  /// Batch-deletes a list of tasks in one atomic SQLite transaction, then
  /// cancels their notifications in parallel. Far faster than N serial
  /// `deleteTask()` calls for multi-select batch operations.
  Future<void> batchDeleteTasks(List<RoutineTask> tasks) async {
    if (tasks.isEmpty) return;

    // 1. Single SQLite batch transaction
    await _databaseService.batchDeleteTasks(tasks.map((t) => t.id).toList());

    // 2. Cancel all notifications in parallel (fire-and-forget)
    Future.wait([
      for (final task in tasks) ...[
        NotificationService.cancelSingleNotification(task.id),
        NotificationService.cancelRoutineTaskNotifications(task.id),
      ]
    ]).ignore();

    // 3. Delete from Google Calendar in parallel (non-blocking)
    for (final task in tasks) {
      if (task.googleEventId != null && _authService.isSignedIn) {
        _googleCalendarService
            .deleteCalendarEvent(task.googleEventId)
            .catchError((_) {});
      }
    }

    // 4. Delete from Cloud Firestore in parallel (non-blocking)
    for (final task in tasks) {
      _cloudSyncService?.deleteTask(task.id);
    }
  }

  /// Batch-updates a list of tasks (day-scoped) in one atomic SQLite transaction,
  /// then reschedules notifications in parallel.
  Future<void> batchUpdateTasks(List<RoutineTask> tasks) async {
    if (tasks.isEmpty) return;

    // 1. Single SQLite batch update
    await _databaseService.batchUpdateTasks(tasks);

    // 2. Reschedule notifications in parallel (fire-and-forget)
    Future.wait([
      for (final task in tasks)
        _rescheduleSingleTaskNotification(task),
    ]).ignore();

    // 3. Dual-write to Cloud Firestore in parallel (non-blocking)
    for (final task in tasks) {
      _cloudSyncService?.uploadTask(task);
    }
  }

  Future<void> _rescheduleSingleTaskNotification(RoutineTask task) async {
    await NotificationService.cancelSingleNotification(task.id);
    await NotificationService.cancelRoutineTaskNotifications(task.id);
    if (task.isReminder) {
      if (NotificationSettingsController.instance.reminderNotificationsEnabled) {
        final notifId = NotificationService.getNotificationId(task.id);
        await _notificationService.scheduleExactReminder(
          id: notifId,
          title: 'Reminder: ${task.title}',
          body: 'Time for your ${task.category} reminder',
          scheduledDateTime: task.startTime,
        );
      }
    } else {
      if (NotificationSettingsController.instance.routineNotificationsEnabled) {
        for (final day in task.daysOfWeek) {
          final notifId = NotificationService.getNotificationId(task.id, day);
          await _notificationService.scheduleWeeklyReminder(
            id: notifId,
            title: 'Routine: ${task.title}',
            body: 'Time for your ${task.category} routine',
            hour: task.startTime.toLocal().hour,
            minute: task.startTime.toLocal().minute,
            dayOfWeek: day,
          );
        }
      }
    }
  }

  /// Batch-restores a list of deleted tasks in one atomic SQLite transaction,
  /// then reschedules their notifications in parallel. Used for multi-select UNDO.
  Future<void> batchRestoreTasks(List<RoutineTask> tasks) async {
    if (tasks.isEmpty) return;

    // 1. Single SQLite batch insert
    await _databaseService.batchInsertTasks(tasks);

    // 2. Schedule notifications in parallel (fire-and-forget)
    Future.wait([
      for (final task in tasks) _rescheduleSingleTaskNotification(task),
    ]).ignore();

    // 3. Dual-write to Cloud Firestore in parallel (non-blocking)
    for (final task in tasks) {
      _cloudSyncService?.uploadTask(task);
    }
  }


  Future<List<RoutineTask>> fetchTasksForWeekday(int weekday) async {
    return await _databaseService.getTasksForDay(weekday);
  }

  /// Backward-compatible alias for deleteRoutine.
  Future<void> deleteRoutine(RoutineTask task) => deleteTask(task);

  /// Retrieves local daily recurring routines, applying midnight auto-reset logic.
  Future<List<RoutineTask>> getRoutines() async {
    final rawTasks = await _databaseService.getTasksByType(TaskType.routine);
    final today = RoutineTask.todayDateString;

    return rawTasks.map((task) {
      // If the task was completed on a previous day, project isCompleted = false.
      if (task.lastCompletedDate != null && task.lastCompletedDate != today) {
        return task.copyWith(isCompleted: false);
      }
      return task;
    }).toList();
  }

  /// Retrieves one-time reminders.
  Future<List<RoutineTask>> getReminders() async {
    return await _databaseService.getReminders();
  }

  /// Upserts a task locally into SQLite database without triggering cloud writes.
  Future<void> upsertTaskLocally(RoutineTask task) async {
    final db = await _databaseService.database;
    await db.insert(
      DatabaseService.tableRoutineTasks,
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Batch upserts multiple tasks locally into SQLite in a single transaction without creating duplicate records.
  Future<void> batchUpsertTasksLocally(List<RoutineTask> tasks) async {
    await _databaseService.batchSyncTasks(tasks);
  }

  /// Retrieves all tasks stored in SQLite database.
  Future<List<RoutineTask>> getAllTasks() async {
    return await _databaseService.getAllTasks();
  }

  /// Retrieves all tasks regardless of type.
  Future<List<RoutineTask>> getAllRoutines() async {
    return await getRoutines();
  }

  /// Toggles task completion state with midnight-reset-aware persistence and Cloud Firestore dual-sync.
  Future<void> toggleTaskCompletion(RoutineTask task) async {
    final today = RoutineTask.todayDateString;

    // Determine the effective completion state (accounting for midnight reset).
    final effectivelyCompleted = task.isRoutine
        ? (task.lastCompletedDate == today)
        : task.isCompleted;

    final RoutineTask updatedTask;
    if (!effectivelyCompleted) {
      // ── Mark as complete ────────────────────────────────────────────────────
      updatedTask = task.copyWith(
        isCompleted: true,
        lastCompletedDate: () => task.isRoutine ? today : task.lastCompletedDate,
        updatedAt: DateTime.now().toUtc(),
      );
      await _databaseService.updateTask(updatedTask);

      // Auto-insert a TimeLog so Analytics can track focus hours.
      final logId = '${task.id}_$today';
      final log = TimeLog(
        id: logId,
        taskId: task.id,
        timestamp: DateTime.now(),
        durationSpentMinutes: task.durationMinutes,
      );
      await _databaseService.insertTimeLog(log);
    } else {
      // ── Unmark (user unticked) ──────────────────────────────────────────────
      updatedTask = task.copyWith(
        isCompleted: false,
        updatedAt: DateTime.now().toUtc(),
      );
      await _databaseService.updateTask(updatedTask);
    }

    // Dual-write updated completion status to Cloud Firestore (non-blocking)
    try {
      await _cloudSyncService?.uploadTask(updatedTask);
    } catch (_) {}
  }
}
