import 'package:flutter/material.dart';

import '../../calendar_sync/services/auth_service.dart';
import '../../settings/presentation/account_sync_screen.dart';

/// Screen allowing the user to manage their Google Account sign in, backup, and cloud sync settings.
class AccountScreen extends StatelessWidget {
  final AuthService? authService;

  const AccountScreen({
    super.key,
    this.authService,
  });

  @override
  Widget build(BuildContext context) {
    return AccountSyncScreen(authService: authService);
  }
}
