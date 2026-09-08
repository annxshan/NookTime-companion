import 'package:flutter_test/flutter_test.dart';
import 'package:nooktime/features/calendar_sync/repositories/sync_repository.dart';

void main() {
  group('SyncResult Unit Tests', () {
    test('SyncResult properties and string representation', () {
      const result = SyncResult(
        insertedLocally: 3,
        updatedLocally: 1,
        pushedToRemote: 2,
      );

      expect(result.insertedLocally, equals(3));
      expect(result.updatedLocally, equals(1));
      expect(result.pushedToRemote, equals(2));
      expect(
        result.toString(),
        equals('SyncResult(insertedLocally: 3, updatedLocally: 1, pushedToRemote: 2)'),
      );
    });
  });
}
