import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/database_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/notification_settings_controller.dart';
import '../../calendar_sync/services/auth_service.dart';
import '../../calendar_sync/services/google_calendar_service.dart';
import '../../daily_routine/data/routine_repository.dart';
import '../../daily_routine/domain/models/routine_task.dart';
import '../../reminders/data/reminder_repository.dart';


/// Data model summarizing the result of a cloud restore or backup operation.
class SyncSummary {
  final bool isSuccess;
  final int tasksImported;
  final int remindersImported;
  final DateTime? lastSynced;
  final String? errorMessage;

  const SyncSummary({
    required this.isSuccess,
    this.tasksImported = 0,
    this.remindersImported = 0,
    this.lastSynced,
    this.errorMessage,
  });

  factory SyncSummary.success({
    required int tasks,
    required int reminders,
    DateTime? lastSynced,
  }) {
    return SyncSummary(
      isSuccess: true,
      tasksImported: tasks,
      remindersImported: reminders,
      lastSynced: lastSynced ?? DateTime.now(),
    );
  }

  factory SyncSummary.error(String message) {
    return SyncSummary(
      isSuccess: false,
      errorMessage: message,
    );
  }
}

/// Data model capturing the output status and metrics of a cloud sync or restoration run.
class SyncResult {
  final bool isSuccess;
  final bool isUnauthenticated;
  final int tasksImported;
  final int remindersImported;
  final DateTime? lastSyncedAt;
  final String? errorMessage;

  const SyncResult({
    required this.isSuccess,
    this.isUnauthenticated = false,
    this.tasksImported = 0,
    this.remindersImported = 0,
    this.lastSyncedAt,
    this.errorMessage,
  });

  factory SyncResult.success({
    required int tasks,
    required int reminders,
    DateTime? lastSyncedAt,
  }) {
    return SyncResult(
      isSuccess: true,
      tasksImported: tasks,
      remindersImported: reminders,
      lastSyncedAt: lastSyncedAt ?? DateTime.now(),
    );
  }

  factory SyncResult.unauthenticated() {
    return const SyncResult(
      isSuccess: false,
      isUnauthenticated: true,
      errorMessage: 'User is not authenticated',
    );
  }

  factory SyncResult.error(String message) {
    return SyncResult(
      isSuccess: false,
      errorMessage: message,
    );
  }
}

/// Service managing two-way task synchronization, backup-and-restore,
/// and local notification rescheduling between local SQLite database and Cloud Firestore.
class CloudSyncService {
  final FirebaseFirestore? _customFirestore;
  final FirebaseAuth? _customAuth;

  CloudSyncService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _customFirestore = firestore,
        _customAuth = auth;

  /// Lazy safe accessor for [FirebaseFirestore]. Returns null if Firebase is not initialized.
  FirebaseFirestore? get _firestore {
    try {
      return _customFirestore ?? FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  /// Lazy safe accessor for [FirebaseAuth]. Returns null if Firebase is not initialized.
  FirebaseAuth? get _auth {
    try {
      return _customAuth ?? FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  /// Returns the Firebase Auth UID for the currently signed-in user, or null if unauthenticated.
  /// Only Firebase Auth UIDs satisfy Firestore security rules (request.auth.uid).
  String? get _currentUserId {
    try {
      final uid = _auth?.currentUser?.uid;
      if (uid != null && uid.isNotEmpty) return uid;
    } catch (_) {}
    return null;
  }

  /// Helper reference to the `users/{userId}/routines` collection.
  CollectionReference<Map<String, dynamic>>? get _routinesCollection {
    final uid = _currentUserId;
    final fs = _firestore;
    if (uid == null || fs == null) return null;
    return fs.collection('users').doc(uid).collection('routines');
  }

  /// Probe test verifying Cloud Firestore read/write access under `users/{uid}/metadata/probe`.
  Future<bool> testFirestoreConnection() async {
    final uid = _currentUserId;
    final fs = _firestore;
    if (uid == null || fs == null) return false;

    try {
      final probeRef = fs.collection('users').doc(uid).collection('metadata').doc('probe');
      await probeRef.set({
        'probeTimestamp': FieldValue.serverTimestamp(),
        'status': 'connected',
      });
      final snapshot = await probeRef.get();
      return snapshot.exists;
    } catch (e) {
      debugPrint('testFirestoreConnection error: $e');
      return false;
    }
  }

  /// Backs up all local tasks and reminders to Cloud Firestore under `users/{uid}`.
  /// Returns true if backup succeeds, false if unauthenticated, or throws on Firestore error.
  Future<bool> backupToCloud() async {
    final uid = _currentUserId;
    final fs = _firestore;
    if (uid == null || fs == null) {
      debugPrint('backupToCloud: No Firebase Auth session — user must sign in first.');
      return false;
    }

    try {
      await backupLocalDataToCloud();
      return true;
    } catch (e) {
      debugPrint('backupToCloud error: $e');
      rethrow;
    }
  }

  /// Restores user data from Cloud Firestore to local SQLite and reschedules notifications.
  Future<SyncSummary> restoreFromCloud() async {
    final result = await restoreUserDataFromCloud();
    return SyncSummary(
      isSuccess: result.isSuccess,
      tasksImported: result.tasksImported,
      remindersImported: result.remindersImported,
      lastSynced: result.lastSyncedAt,
      errorMessage: result.errorMessage,
    );
  }

  /// Checks if any cloud routine tasks, reminders, or legacy data exist for the logged-in user.
  Future<bool> hasCloudData() async {
    final uid = _currentUserId;
    final fs = _firestore;
    if (uid == null || fs == null) return false;

    try {
      final tasksDoc = await fs.collection('users').doc(uid).collection('routine_tasks').limit(1).get();
      if (tasksDoc.docs.isNotEmpty) return true;

      final remindersDoc = await fs.collection('users').doc(uid).collection('reminders').limit(1).get();
      if (remindersDoc.docs.isNotEmpty) return true;

      final legacyDoc = await fs.collection('users').doc(uid).collection('routines').limit(1).get();
      if (legacyDoc.docs.isNotEmpty) return true;
    } catch (e) {
      debugPrint('hasCloudData error: $e');
    }
    return false;
  }

  /// 1. Full Cloud-to-Local Restore (Triggered on login or manual sync).
  /// Imports all routine tasks & reminders from Cloud Firestore under `users/{uid}` into local SQLite
  /// and automatically reschedules local hardware notification alarms.
  Future<SyncResult> restoreUserDataFromCloud({
    RoutineRepository? routineRepository,
    ReminderRepository? reminderRepository,
    DatabaseService? databaseService,
  }) async {
    final uid = _currentUserId;
    final fs = _firestore;
    if (uid == null || fs == null) {
      return SyncResult.unauthenticated();
    }

    try {
      final dbService = databaseService ?? DatabaseService();
      final routineRepo = routineRepository ??
          RoutineRepository(
            databaseService: dbService,
            notificationService: NotificationService(),
            googleCalendarService: GoogleCalendarService(authService: AuthService()),
            authService: AuthService(),
          );
      final reminderRepo = reminderRepository ??
          ReminderRepository(
            databaseService: dbService,
            notificationService: NotificationService(),
          );

      int importedTasks = 0;
      int importedReminders = 0;

      // Fetch routine_tasks collection from Firestore
      final tasksSnapshot = await fs
          .collection('users')
          .doc(uid)
          .collection('routine_tasks')
          .get();

      for (final doc in tasksSnapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data.remove('updated_at_server');
        try {
          final task = RoutineTask.fromMap(data);
          await routineRepo.upsertTaskLocally(task);

          // Re-register alarms on the new device hardware
          if (NotificationSettingsController.instance.routineNotificationsEnabled) {
            await NotificationService.cancelRoutineTaskNotifications(task.id);
            for (final day in task.daysOfWeek) {
              final notifId = NotificationService.getNotificationId(task.id, day);
              await NotificationService().scheduleWeeklyReminder(
                id: notifId,
                title: 'Routine: ${task.title}',
                body: 'Time for your ${task.category} routine (${task.durationMinutes} mins)',
                hour: task.startTime.toLocal().hour,
                minute: task.startTime.toLocal().minute,
                dayOfWeek: day,
              );
            }
          }
          importedTasks++;
        } catch (e) {
          debugPrint('Doc parse error (routine_tasks): $e');
        }
      }

      // Fetch reminders collection from Firestore
      final remindersSnapshot = await fs
          .collection('users')
          .doc(uid)
          .collection('reminders')
          .get();

      for (final doc in remindersSnapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data.remove('updated_at_server');
        try {
          final reminder = RoutineTask.fromMap(data);
          await reminderRepo.upsertReminderLocally(reminder);

          if (!reminder.isCompleted &&
              NotificationSettingsController.instance.reminderNotificationsEnabled) {
            await NotificationService.cancelSingleNotification(reminder.id);
            final notifId = NotificationService.getNotificationId(reminder.id);
            await NotificationService().scheduleExactReminder(
              id: notifId,
              title: 'Reminder: ${reminder.title}',
              body: 'Scheduled for ${reminder.category}',
              scheduledDateTime: reminder.startTime,
            );
          }
          importedReminders++;
        } catch (e) {
          debugPrint('Doc parse error (reminders): $e');
        }
      }

      // Backward-compatible fallback for existing users/routines collections
      if (importedTasks == 0 && importedReminders == 0) {
        final legacySnapshot = await fs
            .collection('users')
            .doc(uid)
            .collection('routines')
            .get();

        for (final doc in legacySnapshot.docs) {
          final data = Map<String, dynamic>.from(doc.data());
          data.remove('updated_at_server');
          try {
            final task = RoutineTask.fromMap(data);
            await routineRepo.upsertTaskLocally(task);

            if (task.isReminder) {
              if (!task.isCompleted &&
                  NotificationSettingsController.instance.reminderNotificationsEnabled) {
                await NotificationService.cancelSingleNotification(task.id);
                final notifId = NotificationService.getNotificationId(task.id);
                await NotificationService().scheduleExactReminder(
                  id: notifId,
                  title: 'Reminder: ${task.title}',
                  body: 'Scheduled for ${task.category}',
                  scheduledDateTime: task.startTime,
                );
              }
              importedReminders++;
            } else {
              if (NotificationSettingsController.instance.routineNotificationsEnabled) {
                await NotificationService.cancelRoutineTaskNotifications(task.id);
                for (final day in task.daysOfWeek) {
                  final notifId = NotificationService.getNotificationId(task.id, day);
                  await NotificationService().scheduleWeeklyReminder(
                    id: notifId,
                    title: 'Routine: ${task.title}',
                    body: 'Time for your ${task.category} routine (${task.durationMinutes} mins)',
                    hour: task.startTime.toLocal().hour,
                    minute: task.startTime.toLocal().minute,
                    dayOfWeek: day,
                  );
                }
              }
              importedTasks++;
            }
          } catch (_) {}
        }
      }

      // Update sync metadata document
      final syncTime = DateTime.now().toUtc();
      await fs
          .collection('users')
          .doc(uid)
          .collection('metadata')
          .doc('sync_info')
          .set({
        'lastSyncedAt': syncTime.toIso8601String(),
        'deviceInfo': kIsWeb ? 'Web Browser' : defaultTargetPlatform.name,
        'taskCount': importedTasks,
        'reminderCount': importedReminders,
      }, SetOptions(merge: true));

      return SyncResult.success(
        tasks: importedTasks,
        reminders: importedReminders,
        lastSyncedAt: syncTime,
      );
    } catch (e) {
      debugPrint('restoreUserDataFromCloud error: $e');
      return SyncResult.error(e.toString());
    }
  }

  /// 2. Backup Local Data to Cloud.
  /// Batch exports all local tasks & reminders from SQLite to Cloud Firestore under `users/{uid}`.
  Future<void> backupLocalDataToCloud({
    RoutineRepository? routineRepository,
    ReminderRepository? reminderRepository,
    DatabaseService? databaseService,
  }) async {
    final uid = _currentUserId;
    final fs = _firestore;
    if (uid == null || fs == null) return;

    try {
      final dbService = databaseService ?? DatabaseService();
      final routineRepo = routineRepository ??
          RoutineRepository(
            databaseService: dbService,
            notificationService: NotificationService(),
            googleCalendarService: GoogleCalendarService(authService: AuthService()),
            authService: AuthService(),
          );
      final reminderRepo = reminderRepository ??
          ReminderRepository(
            databaseService: dbService,
            notificationService: NotificationService(),
          );

      final localTasks = await routineRepo.getAllTasks();
      final localReminders = await reminderRepo.getReminders();

      final batch = fs.batch();
      final routineCollection = fs.collection('users').doc(uid).collection('routine_tasks');
      final reminderCollection = fs.collection('users').doc(uid).collection('reminders');

      int taskCount = 0;
      for (final task in localTasks.where((t) => t.isRoutine)) {
        final docRef = routineCollection.doc(task.id);
        final data = task.toMap();
        data['updated_at_server'] = FieldValue.serverTimestamp();
        batch.set(docRef, data, SetOptions(merge: true));
        taskCount++;
      }

      int reminderCount = 0;
      for (final reminder in localReminders) {
        final docRef = reminderCollection.doc(reminder.id);
        final data = reminder.toMap();
        data['updated_at_server'] = FieldValue.serverTimestamp();
        batch.set(docRef, data, SetOptions(merge: true));
        reminderCount++;
      }

      // Purge any remote documents from Cloud Firestore that no longer exist in local SQLite
      final localTaskIds = localTasks.where((t) => t.isRoutine).map((t) => t.id).toSet();
      final remoteTasksSnapshot = await routineCollection.get();
      for (final doc in remoteTasksSnapshot.docs) {
        if (!localTaskIds.contains(doc.id)) {
          batch.delete(doc.reference);
        }
      }

      final localReminderIds = localReminders.map((r) => r.id).toSet();
      final remoteRemindersSnapshot = await reminderCollection.get();
      for (final doc in remoteRemindersSnapshot.docs) {
        if (!localReminderIds.contains(doc.id)) {
          batch.delete(doc.reference);
        }
      }

      final syncInfoRef =
          fs.collection('users').doc(uid).collection('metadata').doc('sync_info');
      final syncTime = DateTime.now().toUtc();
      batch.set(syncInfoRef, {
        'lastSynced': FieldValue.serverTimestamp(),
        'lastSyncedAt': syncTime.toIso8601String(),
        'deviceInfo': kIsWeb ? 'Web Browser' : defaultTargetPlatform.name,
        'taskCount': taskCount,
        'reminderCount': reminderCount,
      }, SetOptions(merge: true));

      await batch.commit();
    } catch (e) {
      debugPrint('backupLocalDataToCloud error: $e');
    }
  }

  /// Uploads or merges a single [RoutineTask] to Cloud Firestore.
  /// Includes a `serverTimestamp` field for remote tracking.
  Future<void> uploadTask(RoutineTask task) async {
    try {
      final collection = _routinesCollection;
      if (collection == null) return;

      final data = task.toMap();
      data['updated_at_server'] = FieldValue.serverTimestamp();

      await collection.doc(task.id).set(
            data,
            SetOptions(merge: true),
          );

      // Dual write to type specific collection
      final uid = _currentUserId;
      final fs = _firestore;
      if (uid != null && fs != null) {
        final subCol = task.isReminder ? 'reminders' : 'routine_tasks';
        await fs.collection('users').doc(uid).collection(subCol).doc(task.id).set(
              data,
              SetOptions(merge: true),
            );
      }
    } catch (e) {
      debugPrint('CloudSync uploadTask notice: $e');
    }
  }

  /// Deletes a task document by [taskId] from Cloud Firestore if user is logged in.
  /// Deletes a task document by [taskId] from Cloud Firestore if user is logged in.
  /// Uses an atomic batch delete across all Firestore collections (`routine_tasks`, `reminders`, `routines`).
  Future<void> deleteTask(String taskId) async {
    final uid = _currentUserId;
    final fs = _firestore;
    if (uid == null || fs == null) return;

    try {
      final batch = fs.batch();

      // Delete from main users/{uid}/routines collection
      final legacyRef = fs.collection('users').doc(uid).collection('routines').doc(taskId);
      batch.delete(legacyRef);

      // Delete from type-specific routine_tasks collection
      final taskRef = fs.collection('users').doc(uid).collection('routine_tasks').doc(taskId);
      batch.delete(taskRef);

      // Delete from reminders collection
      final reminderRef = fs.collection('users').doc(uid).collection('reminders').doc(taskId);
      batch.delete(reminderRef);

      await batch.commit();
    } catch (e) {
      debugPrint('CloudSync deleteTask notice: $e');
    }
  }

  /// Uploads all local tasks to Cloud Firestore using an efficient `WriteBatch`.
  Future<void> uploadAllLocalTasks(List<RoutineTask> tasks) async {
    try {
      final collection = _routinesCollection;
      final fs = _firestore;
      if (collection == null || fs == null || tasks.isEmpty) return;

      final batch = fs.batch();

      for (final task in tasks) {
        final docRef = collection.doc(task.id);
        final data = task.toMap();
        data['updated_at_server'] = FieldValue.serverTimestamp();
        batch.set(docRef, data, SetOptions(merge: true));

        final uid = _currentUserId;
        if (uid != null) {
          final subCol = task.isReminder ? 'reminders' : 'routine_tasks';
          final subRef = fs.collection('users').doc(uid).collection(subCol).doc(task.id);
          batch.set(subRef, data, SetOptions(merge: true));
        }
      }

      await batch.commit();
    } catch (e) {
      debugPrint('CloudSync uploadAllLocalTasks notice: $e');
    }
  }

  /// Fetches all task documents from Cloud Firestore `users/{userId}/routines`
  /// and mirrors them into the local SQLite database via [dbService].
  Future<void> syncFromCloudToLocal(DatabaseService dbService) async {
    await restoreUserDataFromCloud(databaseService: dbService);
  }
}

