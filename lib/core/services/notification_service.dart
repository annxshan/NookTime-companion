import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Singleton service managing on-device local notifications and daily/weekly alarm scheduling.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  /// Static reference to plugin instance for global access & static cancellation calls.
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Deterministic 32-bit integer ID generator from String IDs
  static int getNotificationId(String id, [int? dayOfWeek]) {
    final int baseHash = id.hashCode & 0x7FFFFFFF;
    if (dayOfWeek != null) {
      return ((baseHash % 100000) * 10) + dayOfWeek;
    }
    return baseHash % 1000000;
  }

  /// Cancel single one-time notification (Reminders)
  static Future<void> cancelSingleNotification(String reminderId) async {
    if (kIsWeb) return;
    final int id = getNotificationId(reminderId);
    try {
      await flutterLocalNotificationsPlugin.cancel(id);
    } catch (_) {}
  }

  /// Cancel all recurring weekday alarms for a routine task (Days 1 to 7)
  static Future<void> cancelRoutineTaskNotifications(String taskId) async {
    if (kIsWeb) return;
    // Loop through all 7 weekdays to ensure all possible recurring instances are removed
    for (int day = 1; day <= 7; day++) {
      final int id = getNotificationId(taskId, day);
      try {
        await flutterLocalNotificationsPlugin.cancel(id);
      } catch (_) {}
    }
  }

  /// Clear all pending scheduled notifications (Used when applying a full new schedule)
  static Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    try {
      await flutterLocalNotificationsPlugin.cancelAll();
    } catch (_) {}
  }

  /// Initializes the local notifications plugin, timezone database, and notification channels.
  Future<void> initialize() async {
    if (kIsWeb) return;
    if (_isInitialized) return;

    // Initialize timezone database and set device local timezone
    tz.initializeTimeZones();
    try {
      final timeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZone.identifier));
    } catch (_) {
      // Fallback to UTC if timezone resolution is unavailable
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(initSettings);

    final androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      const channel = AndroidNotificationChannel(
        'nooktime_routine_channel',
        'Daily Routine Reminders',
        description: 'On-device notifications for scheduled routines',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );
      await androidImplementation.createNotificationChannel(channel);
      await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();
    }

    final darwinImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (darwinImplementation != null) {
      await darwinImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    _isInitialized = true;
  }

  /// Displays an immediate local notification (useful for instant verification).
  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    await initialize();

    final safeId = id.abs() & 0x7FFFFFFF;

    const androidDetails = AndroidNotificationDetails(
      'nooktime_routine_channel',
      'Daily Routine Reminders',
      channelDescription: 'On-device notifications for scheduled routines',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await flutterLocalNotificationsPlugin.show(
      safeId,
      title,
      body,
      notificationDetails,
    );
  }

  /// Schedules a recurring daily local reminder at the specified [hour] and [minute].
  Future<void> scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    if (kIsWeb) return;
    await initialize();

    final safeId = id.abs() & 0x7FFFFFFF;

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'nooktime_routine_channel',
      'Daily Routine Reminders',
      channelDescription: 'On-device notifications for scheduled routines',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      safeId,
      title,
      body,
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Schedules a weekly recurring local reminder for a specific [dayOfWeek] (1 = Mon, ..., 7 = Sun) at [hour] and [minute].
  Future<void> scheduleWeeklyReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required int dayOfWeek,
  }) async {
    if (kIsWeb) return;
    await initialize();

    final safeId = id.abs() & 0x7FFFFFFF;

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    while (scheduledDate.weekday != dayOfWeek || scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'nooktime_routine_channel',
      'Daily Routine Reminders',
      channelDescription: 'On-device notifications for scheduled routines',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      safeId,
      title,
      body,
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  /// Schedules a one-shot exact local reminder for a specific date and time.
  /// Does NOT repeat daily. Fires only at [scheduledDateTime].
  Future<void> scheduleExactReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDateTime,
  }) async {
    if (kIsWeb) return;
    await initialize();

    final safeId = id.abs() & 0x7FFFFFFF;
    final scheduledDate = tz.TZDateTime.from(scheduledDateTime, tz.local);

    // If target date/time has already passed, skip scheduling
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'nooktime_reminder_channel',
      'Exact Date & Time Reminders',
      channelDescription: 'On-device notifications for exact date & time reminders',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      safeId,
      title,
      body,
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      // No matchDateTimeComponents -> Fires ONCE at exact date & time!
    );
  }

  /// Cancels a scheduled local reminder by its unique notification [id].
  Future<void> cancelReminder(int id) async {
    if (kIsWeb) return;
    await initialize();
    final safeId = id.abs() & 0x7FFFFFFF;
    await flutterLocalNotificationsPlugin.cancel(safeId);
  }

  /// Cancels all scheduled local reminders.
  Future<void> cancelAllReminders() async {
    await cancelAllNotifications();
  }
}

