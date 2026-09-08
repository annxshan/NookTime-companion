import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nooktime/features/settings/presentation/account_sync_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AccountSyncScreen renders header badge, metrics card, and action buttons',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AccountSyncScreen(),
      ),
    );

    expect(find.text('Account & Cloud Sync'), findsOneWidget);
    expect(find.text('SYNC OVERVIEW'), findsOneWidget);
    expect(find.textContaining('LOCAL MODE ONLY'), findsOneWidget);
    expect(find.textContaining('Backup'), findsWidgets);
    expect(find.textContaining('Restore'), findsWidgets);
  });
}
