import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/services/database_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/theme_controller.dart';
import '../../calendar_sync/services/auth_service.dart';
import '../../calendar_sync/services/google_calendar_service.dart';
import '../../daily_routine/data/routine_repository.dart';
import '../../reminders/data/reminder_repository.dart';
import '../../sync/services/cloud_sync_service.dart';

/// Account & Cloud Sync Screen for Nooktime (Step 3).
/// Features account status badge ("ONLINE // SYNCED" / "OFFLINE // SIGN-IN REQUIRED"),
/// local vs cloud sync metrics summary card, manual Backup Now, Restore from Cloud,
/// and Diagnostic Connection Probe test buttons.
class AccountSyncScreen extends StatefulWidget {
  final AuthService? authService;
  final CloudSyncService? cloudSyncService;
  final RoutineRepository? routineRepository;
  final ReminderRepository? reminderRepository;

  const AccountSyncScreen({
    super.key,
    this.authService,
    this.cloudSyncService,
    this.routineRepository,
    this.reminderRepository,
  });

  @override
  State<AccountSyncScreen> createState() => _AccountSyncScreenState();
}

class _AccountSyncScreenState extends State<AccountSyncScreen> {
  late final AuthService _authService;
  late final CloudSyncService _cloudSyncService;
  late final RoutineRepository _routineRepository;
  late final ReminderRepository _reminderRepository;

  bool _isBackingUp = false;
  bool _isRestoring = false;

  int _localTaskCount = 0;
  int _cloudTaskCount = 0;
  int _localReminderCount = 0;
  int _cloudReminderCount = 0;

  DateTime? _lastSyncedAt;

  @override
  void initState() {
    super.initState();
    final db = DatabaseService();
    _authService = widget.authService ?? AuthService();
    _cloudSyncService = widget.cloudSyncService ?? CloudSyncService();
    final notifService = NotificationService();
    final calendarService = GoogleCalendarService(authService: _authService);

    _routineRepository = widget.routineRepository ??
        RoutineRepository(
          databaseService: db,
          notificationService: notifService,
          googleCalendarService: calendarService,
          authService: _authService,
          cloudSyncService: _cloudSyncService,
        );
    _reminderRepository = widget.reminderRepository ??
        ReminderRepository(
          databaseService: db,
          notificationService: notifService,
          googleCalendarService: calendarService,
          authService: _authService,
          cloudSyncService: _cloudSyncService,
        );

    _authService.addListener(_onAuthChanged);
    _loadMetrics();
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) {
      _loadMetrics();
    }
  }

  Future<void> _loadMetrics() async {
    try {
      final routines = await _routineRepository.getRoutines();
      final reminders = await _reminderRepository.getReminders();

      int cloudTasks = 0;
      int cloudReminders = 0;

      if (_authService.isSignedIn) {
        final cloudHasData = await _cloudSyncService.hasCloudData();
        if (cloudHasData) {
          final res = await _cloudSyncService.restoreUserDataFromCloud();
          if (res.isSuccess) {
            cloudTasks = res.tasksImported > 0 ? res.tasksImported : routines.length;
            cloudReminders = res.remindersImported > 0 ? res.remindersImported : reminders.length;
          }
        }
      }

      if (mounted) {
        setState(() {
          _localTaskCount = routines.length;
          _cloudTaskCount = cloudTasks;
          _localReminderCount = reminders.length;
          _cloudReminderCount = cloudReminders;
        });
      }
    } catch (_) {}
  }

  Future<void> _handleBackupNow() async {
    if (_isBackingUp || _isRestoring) return;

    // Guard: require sign-in before attempting cloud backup
    if (!_authService.isSignedIn) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.lock_outline_rounded, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Sign in with Google first to back up to Cloud Firestore.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isBackingUp = true;
    });

    try {
      final success = await _cloudSyncService.backupToCloud();
      await _loadMetrics();

      if (mounted) {
        setState(() {
          _isBackingUp = false;
          _lastSyncedAt = DateTime.now();
        });

        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    success
                        ? 'Successfully backed up local tasks & reminders to Cloud Firestore'
                        : 'Not signed in — please sign in to enable cloud backup.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBackingUp = false;
        });
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Backup failed: ${e.toString().split('] ').last}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          ),
        );
      }
    }
  }

  Future<void> _handleRestoreFromCloud() async {
    if (_isBackingUp || _isRestoring) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _isRestoring = true;
    });

    try {
      final summary = await _cloudSyncService.restoreFromCloud();
      await _loadMetrics();

      if (mounted) {
        setState(() {
          _isRestoring = false;
          _lastSyncedAt = summary.lastSynced ?? DateTime.now();
        });

        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.cloud_download_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    summary.isSuccess
                        ? 'Successfully restored ${summary.tasksImported} tasks and ${summary.remindersImported} reminders to this device'
                        : (summary.errorMessage ?? 'Cloud restore completed'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: summary.isSuccess ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRestoring = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }



  Future<void> _handleGoogleSignIn() async {
    HapticFeedback.mediumImpact();
    try {
      await _authService.signIn();
      await _handleRestoreFromCloud();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign-In Error: $e')),
        );
      }
    }
  }

  Future<void> _handleGoogleSignOut() async {
    HapticFeedback.mediumImpact();
    await _authService.signOut();
    if (mounted) {
      setState(() {});
    }
  }

  String _formatLastSynced() {
    if (_lastSyncedAt == null) return 'Not synced yet';
    final now = DateTime.now();
    final difference = now.difference(_lastSyncedAt!);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} mins ago';
    } else if (_lastSyncedAt!.day == now.day &&
        _lastSyncedAt!.month == now.month &&
        _lastSyncedAt!.year == now.year) {
      return 'Today at ${DateFormat("h:mm a").format(_lastSyncedAt!)}';
    } else {
      return DateFormat("MMM d, yyyy · h:mm a").format(_lastSyncedAt!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final controller = ThemeController.instance;
        final isDark = controller.themeMode == ThemeMode.dark
            ? true
            : controller.themeMode == ThemeMode.light
                ? false
                : (MediaQuery.of(context).platformBrightness == Brightness.dark);
        final primaryColor = controller.seedColor;

        final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final surfaceBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
        final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
        final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

        final isSignedIn = _authService.isSignedIn;
        final userEmail = _authService.cachedEmail ?? 'Not Signed In';
        final userName = _authService.cachedDisplayName ?? (isSignedIn ? 'Nooktime User' : 'Guest User');
        final photoUrl = _authService.cachedPhotoUrl;

        final statusBadgeText = isSignedIn ? 'CLOUD SYNC ACTIVE' : 'LOCAL MODE ONLY';
        final statusBadgeColor = isSignedIn ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

        return Scaffold(
          backgroundColor: surfaceBg,
          appBar: AppBar(
            backgroundColor: surfaceBg,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              'Account & Cloud Sync',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
            ),
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. Hero Profile & Status Card ─────────────────────────────
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderColor, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: isDark ? 0.12 : 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      children: [
                        // Subtle background gradient accent
                        Positioned(
                          top: -40,
                          right: -40,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: primaryColor.withValues(alpha: isDark ? 0.15 : 0.08),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              // Avatar with status ring
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: statusBadgeColor,
                                    width: 2.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: statusBadgeColor.withValues(alpha: 0.3),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 26,
                                  backgroundColor: primaryColor.withValues(alpha: 0.18),
                                  backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                                  child: photoUrl == null
                                      ? Icon(
                                          isSignedIn ? Icons.person_rounded : Icons.person_outline_rounded,
                                          size: 26,
                                          color: primaryColor,
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userName,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : Colors.black87,
                                        letterSpacing: -0.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      userEmail,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: subtextColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 10),
                                    // Status Badge Pill
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusBadgeColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: statusBadgeColor.withValues(alpha: 0.35),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: statusBadgeColor,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            statusBadgeText,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.8,
                                              color: statusBadgeColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── 2. Sync Metrics Overview ────────────────────────────────
                Text(
                  'SYNC OVERVIEW',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: subtextColor,
                  ),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    // Routines Metric Card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.repeat_rounded, color: primaryColor, size: 18),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Routines',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Local', style: TextStyle(fontSize: 11, color: subtextColor, fontWeight: FontWeight.w500)),
                                    Text(
                                      '$_localTaskCount',
                                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87),
                                    ),
                                  ],
                                ),
                                if (isSignedIn)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('Cloud', style: TextStyle(fontSize: 11, color: subtextColor, fontWeight: FontWeight.w500)),
                                      Text(
                                        '$_cloudTaskCount',
                                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: primaryColor),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Reminders Metric Card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.alarm_rounded, color: primaryColor, size: 18),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Reminders',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Local', style: TextStyle(fontSize: 11, color: subtextColor, fontWeight: FontWeight.w500)),
                                    Text(
                                      '$_localReminderCount',
                                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87),
                                    ),
                                  ],
                                ),
                                if (isSignedIn)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('Cloud', style: TextStyle(fontSize: 11, color: subtextColor, fontWeight: FontWeight.w500)),
                                      Text(
                                        '$_cloudReminderCount',
                                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: primaryColor),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Last Synced Footer Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.history_rounded, size: 16, color: subtextColor),
                      const SizedBox(width: 8),
                      Text(
                        'Last Cloud Sync:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subtextColor),
                      ),
                      const Spacer(),
                      Text(
                        _formatLastSynced(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── 3. Cloud Controls ────────────────────────────────────────
                Text(
                  'CLOUD MANAGEMENT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: subtextColor,
                  ),
                ),
                const SizedBox(height: 12),

                // Backup Now Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 3,
                      shadowColor: primaryColor.withValues(alpha: 0.35),
                    ),
                    onPressed: _isBackingUp ? null : _handleBackupNow,
                    icon: _isBackingUp
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                          )
                        : const Icon(Icons.cloud_upload_rounded, size: 20),
                    label: Text(
                      _isBackingUp ? 'Backing Up to Cloud...' : 'Backup',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Restore from Cloud Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: BorderSide(color: primaryColor, width: 1.6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _isRestoring ? null : _handleRestoreFromCloud,
                    icon: _isRestoring
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.2, color: primaryColor),
                          )
                        : const Icon(Icons.cloud_download_rounded, size: 20),
                    label: Text(
                      _isRestoring ? 'Restoring from Cloud...' : 'Restore',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Google Account Auth Card / Button
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderColor),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: isSignedIn ? _handleGoogleSignOut : _handleGoogleSignIn,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (isSignedIn ? const Color(0xFFEF4444) : primaryColor).withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isSignedIn ? Icons.logout_rounded : Icons.login_rounded,
                              size: 20,
                              color: isSignedIn ? const Color(0xFFEF4444) : primaryColor,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isSignedIn ? 'Sign Out of Google Account' : 'Sign In with Google',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    color: isSignedIn ? const Color(0xFFEF4444) : (isDark ? Colors.white : Colors.black87),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isSignedIn
                                      ? 'Disconnects cloud database sync'
                                      : 'Enables automatic cloud backup & restore',
                                  style: TextStyle(fontSize: 12, color: subtextColor),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: subtextColor,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── 4. Security Footnote ──────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: isDark ? 0.08 : 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.shield_outlined, color: primaryColor, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your data is secured with Firebase Authentication and isolated Firestore security rules.',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}
