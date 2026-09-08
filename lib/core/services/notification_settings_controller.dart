import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controller for managing user preferences for Routine and Reminder push notifications.
class NotificationSettingsController extends ChangeNotifier {
  static const String keyRoutineNotifications = 'routine_notifications_enabled';
  static const String keyReminderNotifications = 'reminder_notifications_enabled';

  bool _routineNotificationsEnabled = true;
  bool _reminderNotificationsEnabled = true;

  bool get routineNotificationsEnabled => _routineNotificationsEnabled;
  bool get reminderNotificationsEnabled => _reminderNotificationsEnabled;

  static final NotificationSettingsController instance =
      NotificationSettingsController._internal();

  factory NotificationSettingsController() => instance;

  NotificationSettingsController._internal();

  /// Loads notification preferences from SharedPreferences.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _routineNotificationsEnabled =
        prefs.getBool(keyRoutineNotifications) ?? true;
    _reminderNotificationsEnabled =
        prefs.getBool(keyReminderNotifications) ?? true;
    notifyListeners();
  }

  /// Toggles Routine task notifications.
  Future<void> setRoutineNotificationsEnabled(bool enabled) async {
    if (_routineNotificationsEnabled == enabled) return;
    _routineNotificationsEnabled = enabled;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyRoutineNotifications, enabled);

    if (!enabled) {
      // If disabled, cancel routine notifications if needed
    }
  }

  /// Toggles Reminder task notifications.
  Future<void> setReminderNotificationsEnabled(bool enabled) async {
    if (_reminderNotificationsEnabled == enabled) return;
    _reminderNotificationsEnabled = enabled;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyReminderNotifications, enabled);

    if (!enabled) {
      // If disabled, cancel reminder notifications if needed
    }
  }

  String get summaryText {
    final rStr = _routineNotificationsEnabled ? 'ON' : 'OFF';
    final remStr = _reminderNotificationsEnabled ? 'ON' : 'OFF';
    return 'Routines: $rStr · Reminders: $remStr';
  }
}
