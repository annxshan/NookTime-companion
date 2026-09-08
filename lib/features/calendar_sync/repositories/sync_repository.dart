import 'package:googleapis/calendar/v3.dart' as calendar;

import '../../../core/services/database_service.dart';
import '../../daily_routine/domain/models/routine_task.dart';
import '../../daily_routine/domain/models/task_type.dart';
import '../services/google_calendar_service.dart';

/// Coordinator executing bi-directional synchronization between local SQLite
/// storage and Google Calendar API for Reminders ONLY.
class SyncRepository {
  final DatabaseService _databaseService;
  final GoogleCalendarService _googleCalendarService;

  SyncRepository({
    required DatabaseService databaseService,
    required GoogleCalendarService googleCalendarService,
  })  : _databaseService = databaseService,
        _googleCalendarService = googleCalendarService;

  /// Executes full bi-directional synchronization within [startDate] and [endDate].
  ///
  /// Only syncing one-time Reminders (Routines are strictly local-only).
  Future<SyncResult> synchronize({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    int insertedCount = 0;
    int updatedCount = 0;
    int pushedCount = 0;

    // 1. Fetch local reminders and remote events for the date window
    final List<RoutineTask> localReminders =
        await _databaseService.getReminders();
    final List<calendar.Event> remoteEvents = await _googleCalendarService
        .fetchPrimaryCalendarEvents(startDate, endDate);

    // Map local reminders by Google Event ID
    final Map<String, RoutineTask> localSyncedMap = {
      for (var t in localReminders)
        if (t.googleEventId != null) t.googleEventId!: t
    };

    final List<RoutineTask> toUpdateLocally = [];
    final List<RoutineTask> toInsertLocally = [];

    // 2. Process remote events -> reconcile with local state
    for (final remoteEvent in remoteEvents) {
      if (remoteEvent.id == null || remoteEvent.status == 'cancelled') {
        continue;
      }

      final String eventId = remoteEvent.id!;
      final DateTime? remoteUpdated = remoteEvent.updated;

      // Convert Google Event to a Reminder RoutineTask object
      final RoutineTask convertedTask = _eventToReminderTask(remoteEvent);

      final RoutineTask? localMatchingTask = localSyncedMap[eventId];

      if (localMatchingTask == null) {
        // Event exists remotely but not locally -> Insert locally as reminder
        toInsertLocally.add(convertedTask);
        insertedCount++;
      } else {
        // Event exists both locally and remotely -> Resolve conflict
        if (remoteUpdated != null &&
            remoteUpdated.isAfter(localMatchingTask.updatedAt)) {
          // Remote is newer -> overwrite local with remote
          toUpdateLocally.add(convertedTask.copyWith(id: localMatchingTask.id));
          updatedCount++;
        } else if (localMatchingTask.updatedAt.isAfter(remoteUpdated ?? DateTime.fromMillisecondsSinceEpoch(0))) {
          // Local is newer -> push update to Google Calendar
          await _googleCalendarService.updateCalendarEvent(localMatchingTask);
          pushedCount++;
        }
      }
    }

    // 3. Process local unsynced reminders -> Push to Google Calendar
    final List<RoutineTask> unsyncedLocalReminders = localReminders
        .where((t) => t.googleEventId == null || t.googleEventId!.isEmpty)
        .toList();

    for (final unsyncedTask in unsyncedLocalReminders) {
      final String? newGoogleId =
          await _googleCalendarService.createCalendarEvent(unsyncedTask);

      if (newGoogleId != null) {
        final updatedTask = unsyncedTask.copyWith(
          googleEventId: () => newGoogleId,
          updatedAt: DateTime.now().toUtc(),
        );
        toUpdateLocally.add(updatedTask);
        pushedCount++;
      }
    }

    // 4. Commit all local database updates in batch transaction
    if (toInsertLocally.isNotEmpty || toUpdateLocally.isNotEmpty) {
      await _databaseService.batchSyncTasks([
        ...toInsertLocally,
        ...toUpdateLocally,
      ]);
    }

    return SyncResult(
      insertedLocally: insertedCount,
      updatedLocally: updatedCount,
      pushedToRemote: pushedCount,
    );
  }

  /// Alias for backward-compatibility
  Future<SyncResult> performSync({
    required DateTime startDate,
    required DateTime endDate,
  }) =>
      synchronize(startDate: startDate, endDate: endDate);

  /// Converts a Google Calendar [calendar.Event] into a local reminder [RoutineTask].
  RoutineTask _eventToReminderTask(calendar.Event event) {
    final startDt = event.start?.dateTime ?? event.start?.date ?? DateTime.now();
    final endDt = event.end?.dateTime ?? event.end?.date ?? startDt.add(const Duration(minutes: 30));

    final duration = endDt.difference(startDt).inMinutes;

    String category = 'Personal';
    if (event.description != null && event.description!.startsWith('Category: ')) {
      category = event.description!.replaceFirst('Category: ', '').trim();
    }

    return RoutineTask(
      id: event.id!,
      title: event.summary ?? 'Untitled Event',
      category: category,
      startTime: startDt.toLocal(),
      durationMinutes: duration > 0 ? duration : 30,
      type: TaskType.reminder,
      isCompleted: false,
      googleEventId: event.id,
      updatedAt: event.updated ?? DateTime.now().toUtc(),
    );
  }
}

/// Summary result of a synchronization execution.
class SyncResult {
  final int insertedLocally;
  final int updatedLocally;
  final int pushedToRemote;

  const SyncResult({
    required this.insertedLocally,
    required this.updatedLocally,
    required this.pushedToRemote,
  });

  @override
  String toString() =>
      'SyncResult(insertedLocally: $insertedLocally, updatedLocally: $updatedLocally, pushedToRemote: $pushedToRemote)';
}
