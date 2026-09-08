import 'package:flutter/material.dart';

import '../repositories/sync_repository.dart';
import '../services/auth_service.dart';

/// Card widget displaying Google Account sign-in status and manual sync trigger.
class CalendarSyncWidget extends StatefulWidget {
  final AuthService authService;
  final SyncRepository syncRepository;
  final VoidCallback? onSyncCompleted;

  const CalendarSyncWidget({
    super.key,
    required this.authService,
    required this.syncRepository,
    this.onSyncCompleted,
  });

  @override
  State<CalendarSyncWidget> createState() => _CalendarSyncWidgetState();
}

class _CalendarSyncWidgetState extends State<CalendarSyncWidget> {
  bool _isSyncing = false;
  bool _isSigningIn = false;
  String? _statusMessage;

  Future<void> _handleSignIn() async {
    setState(() {
      _isSigningIn = true;
      _statusMessage = null;
    });

    try {
      final account = await widget.authService.signIn();
      if (mounted) {
        setState(() {
          _isSigningIn = false;
          if (account != null) {
            _statusMessage = 'Signed in as ${account.email}';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
          _statusMessage = 'Sign-in failed: $e';
        });
      }
    }
  }

  Future<void> _handleSignOut() async {
    await widget.authService.signOut();
    if (mounted) {
      setState(() {
        _statusMessage = 'Signed out';
      });
    }
  }

  Future<void> _handleSyncNow() async {
    if (!widget.authService.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please sign in with Google first.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        ),
      );
      return;
    }

    setState(() {
      _isSyncing = true;
      _statusMessage = null;
    });

    try {
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 7));
      final end = now.add(const Duration(days: 7));

      final result = await widget.syncRepository.synchronize(
        startDate: start,
        endDate: end,
      );

      if (mounted) {
        setState(() {
          _isSyncing = false;
          _statusMessage =
              'Sync completed! (+${result.insertedLocally} local, ^${result.pushedToRemote} remote)';
        });
        widget.onSyncCompleted?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _statusMessage = 'Sync error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = widget.authService.currentUser;
    final isSignedIn = widget.authService.isSignedIn;
    final displayName = user?.displayName ?? widget.authService.cachedDisplayName ?? 'Google Account';
    final email = user?.email ?? widget.authService.cachedEmail ?? '';
    final photoUrl = user?.photoUrl ?? widget.authService.cachedPhotoUrl;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  backgroundImage:
                      photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null
                      ? Icon(
                          isSignedIn ? Icons.person : Icons.calendar_month,
                          color: theme.colorScheme.onPrimaryContainer,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSignedIn
                            ? displayName
                            : 'Google Calendar Sync',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isSignedIn
                            ? email
                            : 'Connect to sync your routines with Google Calendar',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (!isSignedIn)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSigningIn ? null : _handleSignIn,
                      icon: _isSigningIn
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: Text(_isSigningIn ? 'Signing In...' : 'Sign In with Google'),
                    ),
                  )
                else ...[
                  OutlinedButton.icon(
                    onPressed: _handleSignOut,
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Sign Out'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isSyncing ? null : _handleSyncNow,
                      icon: _isSyncing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.sync, size: 18),
                      label: Text(_isSyncing ? 'Syncing...' : 'Sync Now'),
                    ),
                  ),
                ],
              ],
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _statusMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _statusMessage!.contains('error') || _statusMessage!.contains('failed')
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
