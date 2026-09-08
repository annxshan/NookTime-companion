import 'package:sqflite/sqflite.dart';

import '../../../core/services/database_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/notification_settings_controller.dart';
import '../../calendar_sync/services/auth_service.dart';
import '../../calendar_sync/services/google_calendar_service.dart';
import '../../daily_routine/domain/models/routine_task.dart';
import '../../daily_routine/domain/models/task_type.dart';
import '../../sync/services/cloud_sync_service.dart';

/// Repository specifically managing scheduled Reminders (one-time date/time events),
/// system notification cancellations/scheduling, Google Calendar integration, and Cloud sync.
class ReminderRepository {
  final DatabaseService _databaseService;
  final NotificationService _notificationService;
  final GoogleCalendarService? _googleCalendarService;
  final AuthService? _authService;
  final CloudSyncService? _cloudSyncService;

  ReminderRepository({
    required DatabaseService databaseService,
    required NotificationService notificationService,
    GoogleCalendarService? googleCalendarService,
    AuthService? authService,
    CloudSyncService? cloudSyncService,
  })  : _databaseService = databaseService,
        _notificationService = notificationService,
        _googleCalendarService = googleCalendarService,
        _authService = authService,
        _cloudSyncService = cloudSyncService;

  /// Creates a scheduled reminder and handles notification & sync.
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

    await _databaseService.insertTask(reminder);

    // Cancel existing and schedule exact notification
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

    // Google Calendar sync
    if (_authService != null && _authService.isSignedIn && _googleCalendarService != null) {
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
      } catch (_) {}
    }

    try {
      await _cloudSyncService?.uploadTask(reminder);
    } catch (_) {}

    return reminder;
  }

  /// Retrieves all scheduled reminders.
  Future<List<RoutineTask>> getReminders() async {
    return await _databaseService.getReminders();
  }

  /// Alias for getReminders.
  Future<List<RoutineTask>> getAllReminders() => getReminders();

  /// Upserts a reminder locally into SQLite database without triggering cloud writes.
  Future<void> upsertReminderLocally(RoutineTask reminder) async {
    final db = await _databaseService.database;
    await db.insert(
      DatabaseService.tableRoutineTasks,
      reminder.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Batch upserts multiple reminders locally into SQLite in a single transaction without creating duplicate records.
  Future<void> batchUpsertRemindersLocally(List<RoutineTask> reminders) async {
    await _databaseService.batchSyncTasks(reminders);
  }

  /// Updates an existing reminder and ensures pending notifications are canceled.
  Future<void> updateReminder(RoutineTask reminder) async {
    final updatedReminder = reminder.copyWith(
      updatedAt: DateTime.now().toUtc(),
    );

    await _databaseService.updateTask(updatedReminder);

    // Cancel all pending system notifications upon edit
    await NotificationService.cancelSingleNotification(reminder.id);
    await NotificationService.cancelRoutineTaskNotifications(reminder.id);

    if (NotificationSettingsController.instance.reminderNotificationsEnabled) {
      final notifId = NotificationService.getNotificationId(reminder.id);
      await _notificationService.scheduleExactReminder(
        id: notifId,
        title: 'Reminder: ${reminder.title}',
        body: 'Time for your ${reminder.category} reminder',
        scheduledDateTime: reminder.startTime,
      );
    }

    if (reminder.googleEventId != null &&
        _authService != null &&
        _authService.isSignedIn &&
        _googleCalendarService != null) {
      try {
        await _googleCalendarService.updateCalendarEvent(updatedReminder);
      } catch (_) {}
    }

    try {
      await _cloudSyncService?.uploadTask(updatedReminder);
    } catch (_) {}
  }

  /// Deletes a reminder and cancels all pending system notifications.
  Future<void> deleteReminder(RoutineTask reminder) async {
    await _databaseService.deleteTask(reminder.id);

    // Cancel all pending system notifications upon deletion
    await NotificationService.cancelSingleNotification(reminder.id);
    await NotificationService.cancelRoutineTaskNotifications(reminder.id);

    if (reminder.googleEventId != null &&
        _authService != null &&
        _authService.isSignedIn &&
        _googleCalendarService != null) {
      _googleCalendarService.deleteCalendarEvent(reminder.googleEventId).catchError((_) {});
    }

    try {
      _cloudSyncService?.deleteTask(reminder.id);
    } catch (_) {}
  }

  /// Restores a deleted reminder and reschedules notification.
  Future<void> restoreReminder(RoutineTask reminder) async {
    await _databaseService.insertTask(reminder);

    await NotificationService.cancelSingleNotification(reminder.id);
    if (NotificationSettingsController.instance.reminderNotificationsEnabled) {
      final notifId = NotificationService.getNotificationId(reminder.id);
      await _notificationService.scheduleExactReminder(
        id: notifId,
        title: 'Reminder: ${reminder.title}',
        body: 'Scheduled for ${reminder.category}',
        scheduledDateTime: reminder.startTime,
      );
    }

    try {
      await _cloudSyncService?.uploadTask(reminder);
    } catch (_) {}
  }
}
