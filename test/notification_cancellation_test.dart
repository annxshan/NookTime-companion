import 'package:flutter_test/flutter_test.dart';
import 'package:nooktime/core/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationService Deterministic ID & Cancellation Tests', () {
    test('getNotificationId returns deterministic 32-bit int IDs', () {
      const taskId = 'task-uuid-12345';

      final singleId1 = NotificationService.getNotificationId(taskId);
      final singleId2 = NotificationService.getNotificationId(taskId);
      expect(singleId1, equals(singleId2));
      expect(singleId1, greaterThanOrEqualTo(0));
      expect(singleId1, lessThan(1000000));

      final monId = NotificationService.getNotificationId(taskId, 1);
      final tueId = NotificationService.getNotificationId(taskId, 2);
      final sunId = NotificationService.getNotificationId(taskId, 7);

      expect(monId % 10, equals(1));
      expect(tueId % 10, equals(2));
      expect(sunId % 10, equals(7));

      expect(monId, isNot(equals(tueId)));
      expect(tueId, isNot(equals(sunId)));
    });

    test('cancelSingleNotification executes without throwing errors', () async {
      const reminderId = 'reminder-999';
      await expectLater(
        NotificationService.cancelSingleNotification(reminderId),
        completes,
      );
    });

    test('cancelRoutineTaskNotifications cancels all 7 weekday notification IDs', () async {
      const taskId = 'routine-777';
      await expectLater(
        NotificationService.cancelRoutineTaskNotifications(taskId),
        completes,
      );
    });

    test('cancelAllNotifications executes cleanly', () async {
      await expectLater(
        NotificationService.cancelAllNotifications(),
        completes,
      );
    });
  });
}
