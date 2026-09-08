import 'package:flutter_test/flutter_test.dart';
import 'package:nooktime/features/sync/services/cloud_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncSummary & SyncResult Model Tests', () {
    test('SyncSummary.success constructs valid metrics', () {
      final summary = SyncSummary.success(tasks: 4, reminders: 2);
      expect(summary.isSuccess, isTrue);
      expect(summary.tasksImported, equals(4));
      expect(summary.remindersImported, equals(2));
      expect(summary.lastSynced, isNotNull);
      expect(summary.errorMessage, isNull);
    });

    test('SyncSummary.error constructs error state', () {
      final summary = SyncSummary.error('Connection failed');
      expect(summary.isSuccess, isFalse);
      expect(summary.errorMessage, equals('Connection failed'));
    });

    test('SyncResult.success constructs valid result metrics', () {
      final result = SyncResult.success(tasks: 5, reminders: 3);
      expect(result.isSuccess, isTrue);
      expect(result.isUnauthenticated, isFalse);
      expect(result.tasksImported, equals(5));
      expect(result.remindersImported, equals(3));
      expect(result.lastSyncedAt, isNotNull);
      expect(result.errorMessage, isNull);
    });

    test('SyncResult.unauthenticated constructs unauthenticated state', () {
      final result = SyncResult.unauthenticated();
      expect(result.isSuccess, isFalse);
      expect(result.isUnauthenticated, isTrue);
      expect(result.tasksImported, equals(0));
      expect(result.remindersImported, equals(0));
      expect(result.errorMessage, equals('User is not authenticated'));
    });

    test('SyncResult.error constructs error state', () {
      final result = SyncResult.error('Network timeout');
      expect(result.isSuccess, isFalse);
      expect(result.isUnauthenticated, isFalse);
      expect(result.errorMessage, equals('Network timeout'));
    });
  });

  group('CloudSyncService Bidirectional Sync Tests', () {
    test('restoreUserDataFromCloud returns unauthenticated when user is null', () async {
      final cloudService = CloudSyncService();
      final result = await cloudService.restoreUserDataFromCloud();
      expect(result.isSuccess, isFalse);
      expect(result.isUnauthenticated, isTrue);
    });

    test('restoreFromCloud returns error SyncSummary when unauthenticated', () async {
      final cloudService = CloudSyncService();
      final summary = await cloudService.restoreFromCloud();
      expect(summary.isSuccess, isFalse);
      expect(summary.errorMessage, isNotNull);
    });

    test('backupToCloud returns false when user is unauthenticated', () async {
      final cloudService = CloudSyncService();
      final success = await cloudService.backupToCloud();
      expect(success, isFalse);
    });

    test('testFirestoreConnection returns false when user is unauthenticated', () async {
      final cloudService = CloudSyncService();
      final connected = await cloudService.testFirestoreConnection();
      expect(connected, isFalse);
    });
  });
}
