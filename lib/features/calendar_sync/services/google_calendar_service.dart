import 'package:googleapis/calendar/v3.dart' as calendar;

import '../../daily_routine/domain/models/routine_task.dart';
import 'auth_service.dart';

/// Service interfacing directly with Google Calendar API v3.
///
/// Configured to create standard, single-instance events without attaching
/// recurrence rules or Google Calendar push notifications.
class GoogleCalendarService {
  final AuthService _authService;

  GoogleCalendarService({required AuthService authService})
      : _authService = authService;

  /// Helper to acquire an authenticated [calendar.CalendarApi] instance.
  Future<calendar.CalendarApi> _getCalendarApi() async {
    final client = await _authService.getAuthenticatedClient();
    return calendar.CalendarApi(client);
  }

  /// Creates a single, non-recurring Google Calendar event without remote reminders.
  ///
  /// Returns the generated Google Event ID string on success.
  Future<String?> createSingleEvent({
    required String title,
    required String category,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final api = await _getCalendarApi();

    final event = calendar.Event(
      summary: title,
      description: 'Category: $category',
      start: calendar.EventDateTime(
        dateTime: startTime.toUtc(),
        timeZone: 'UTC',
      ),
      end: calendar.EventDateTime(
        dateTime: endTime.toUtc(),
        timeZone: 'UTC',
      ),
      // Expressly disable Google Calendar remote reminders (handled on-device)
      reminders: calendar.EventReminders(
        useDefault: false,
        overrides: [],
      ),
    );

    final createdEvent = await api.events.insert(event, 'primary');
    return createdEvent.id;
  }

  /// Pushes a [RoutineTask] as a single Google Calendar event.
  Future<String?> createCalendarEvent(RoutineTask task) async {
    final endTime = task.startTime.add(Duration(minutes: task.durationMinutes));
    return await createSingleEvent(
      title: task.title,
      category: task.category,
      startTime: task.startTime,
      endTime: endTime,
    );
  }

  /// Updates an existing Google Calendar event corresponding to [task.googleEventId].
  Future<void> updateCalendarEvent(RoutineTask task) async {
    if (task.googleEventId == null || task.googleEventId!.isEmpty) {
      throw ArgumentError('Cannot update event: task has no googleEventId');
    }

    final api = await _getCalendarApi();
    final endTime = task.startTime.add(Duration(minutes: task.durationMinutes));

    final event = calendar.Event(
      summary: task.title,
      description: 'Category: ${task.category}',
      start: calendar.EventDateTime(
        dateTime: task.startTime.toUtc(),
        timeZone: 'UTC',
      ),
      end: calendar.EventDateTime(
        dateTime: endTime.toUtc(),
        timeZone: 'UTC',
      ),
      reminders: calendar.EventReminders(
        useDefault: false,
        overrides: [],
      ),
    );

    await api.events.update(event, 'primary', task.googleEventId!);
  }

  /// Deletes a Google Calendar event by its [googleEventId].
  Future<void> deleteCalendarEvent(String? googleEventId) async {
    if (googleEventId == null || googleEventId.isEmpty) return;

    final api = await _getCalendarApi();
    try {
      await api.events.delete('primary', googleEventId);
    } catch (_) {
      // Ignore 404/410 if event is already removed from Google Calendar
    }
  }

  /// Fetches events from the primary calendar within the specified date range [start] to [end].
  Future<List<calendar.Event>> fetchPrimaryCalendarEvents(
    DateTime start,
    DateTime end,
  ) async {
    final api = await _getCalendarApi();
    final events = await api.events.list(
      'primary',
      timeMin: start.toUtc(),
      timeMax: end.toUtc(),
      singleEvents: true,
      orderBy: 'startTime',
    );

    return events.items ?? [];
  }
}
