import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/notification_settings_controller.dart';
import '../../../core/theme/theme_controller.dart';
import '../../ai_assistant/presentation/widgets/offline_model_download_dialog.dart';
import '../../calendar_sync/repositories/sync_repository.dart';
import '../../calendar_sync/services/auth_service.dart';
import '../../daily_routine/data/routine_repository.dart';
import '../../gamification/services/streak_service.dart';
import '../data/user_profile_repository.dart';
import '../../settings/presentation/widgets/appearance_bottom_sheet.dart';
import '../../settings/presentation/account_sync_screen.dart';
import 'about_nooktime_screen.dart';
import 'edit_profile_screen.dart';

/// Modern, High-End & Aesthetic Profile & Settings Screen for Nooktime.
/// Designed to match the exact visual language, glassmorphism, and color palette of the Routine Dashboard.
class ProfileScreen extends StatefulWidget {
  final AuthService? authService;
  final SyncRepository? syncRepository;
  final RoutineRepository routineRepository;

  const ProfileScreen({
    super.key,
    this.authService,
    this.syncRepository,
    required this.routineRepository,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  UserProfileRepository? _profileRepo;

  String _displayName = '';
  String _designation = '';
  String? _avatarPath;

  int _currentStreak = 0;
  int _totalScheduledMinutesToday = 0;
  int _totalTasks = 0;
  int _completionRate = 0;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileAndStats();
  }

  Future<void> _loadProfileAndStats() async {
    final repo = await UserProfileRepository.create();
    final streakSvc = await StreakService.create();

    final profile = repo.getProfile();
    final curStreak = await streakSvc.getCurrentStreak();

    // Determine name: user profile name -> Google Account name -> empty
    String name = profile.name.trim();
    if (name.isEmpty) {
      final googleName = widget.authService?.currentUser?.displayName ??
          widget.authService?.cachedDisplayName;
      if (googleName != null && googleName.trim().isNotEmpty) {
        name = googleName.trim();
      }
    }

    String designation = profile.designation.trim();

    // Calculate stats specifically for today's active tasks
    final todayWeekday = DateTime.now().weekday;
    final allRoutines = await widget.routineRepository.getRoutines();
    final todayRoutines = allRoutines
        .where((r) => r.isRoutine && r.isScheduledForDay(todayWeekday))
        .toList();

    int totalMins = 0;
    int completedCount = 0;
    for (final r in todayRoutines) {
      totalMins += r.durationMinutes;
      if (r.isCompletedToday) {
        completedCount++;
      }
    }
    final total = todayRoutines.length;
    final rate = total > 0 ? ((completedCount / total) * 100).round() : 0;

    if (mounted) {
      setState(() {
        _profileRepo = repo;
        _displayName = name;
        _designation = designation;
        _avatarPath = profile.avatarPath;
        _currentStreak = curStreak;
        _totalScheduledMinutesToday = totalMins;
        _totalTasks = total;
        _completionRate = rate;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final controller = ThemeController.instance;
        final currentMode = controller.themeMode;
        final isDark = currentMode == ThemeMode.dark
            ? true
            : currentMode == ThemeMode.light
                ? false
                : (MediaQuery.of(context).platformBrightness == Brightness.dark);
        final primaryColor = controller.seedColor;
        final theme = Theme.of(context);

        if (_isLoading) {
          return Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: Center(
              child: CircularProgressIndicator(
                color: primaryColor,
              ),
            ),
          );
        }

        final photoUrl = widget.authService?.currentUser?.photoUrl ??
            widget.authService?.cachedPhotoUrl;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: RefreshIndicator(
            onRefresh: _loadProfileAndStats,
            color: primaryColor,
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: RepaintBoundary(
                    child: _buildMatchingProfileHeader(
                      context,
                      theme,
                      displayName: _displayName,
                      designation: _designation,
                      photoUrl: photoUrl,
                      isDark: isDark,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      RepaintBoundary(
                        child: _buildOverviewCardsGrid(theme, isDark),
                      ),
                      const SizedBox(height: 24),
                      RepaintBoundary(
                        child: _buildGroupedSettingsMenu(context, theme, isDark),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Premium Profile Header Card matching Dashboard glassmorphic container aesthetics
  Widget _buildMatchingProfileHeader(
    BuildContext context,
    ThemeData theme, {
    required String displayName,
    required String designation,
    required String? photoUrl,
    required bool isDark,
  }) {
    final nameToShow = displayName.trim().isNotEmpty ? displayName.trim() : 'User';
    final designationText = designation.trim().isNotEmpty ? designation.trim() : 'Student';
    final primaryColor = ThemeController.instance.seedColor;

    ImageProvider? avatarImageProvider;
    if (_avatarPath != null && _avatarPath!.isNotEmpty) {
      avatarImageProvider = FileImage(File(_avatarPath!));
    } else if (photoUrl != null && photoUrl.isNotEmpty) {
      avatarImageProvider = NetworkImage(photoUrl);
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: isDark
              ? [Color.alphaBlend(primaryColor.withValues(alpha: 0.35), const Color(0xFF0F172A)), const Color(0xFF10172A)]
              : [theme.cardColor, theme.colorScheme.primaryContainer.withValues(alpha: 0.15)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: isDark ? primaryColor.withValues(alpha: 0.35) : Colors.grey.shade300,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Column(
        children: [
          // Avatar Photo
          GestureDetector(
            onTap: _openEditProfileScreen,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [primaryColor, Color.alphaBlend(Colors.black.withValues(alpha: 0.22), primaryColor)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.4),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: CircleAvatar(
                  radius: 42,
                  backgroundColor: isDark ? const Color(0xFF161228) : Colors.white,
                  backgroundImage: avatarImageProvider,
                  child: avatarImageProvider == null
                      ? Text(
                          nameToShow[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: primaryColor,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // User Display Name
          Text(
            nameToShow,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 22,
              letterSpacing: -0.4,
              color: isDark ? const Color(0xFFF1F5F9) : theme.colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),

          // Glowing Designation Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.work_outline_rounded, size: 13, color: primaryColor),
                const SizedBox(width: 6),
                Text(
                  designationText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: primaryColor,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditProfileScreen() async {
    if (_profileRepo == null) return;
    final photoUrl = widget.authService?.currentUser?.photoUrl ??
        widget.authService?.cachedPhotoUrl;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => EditProfileScreen(
          profile: _profileRepo!.getProfile(),
          repository: _profileRepo!,
          photoUrl: photoUrl,
        ),
      ),
    );
    if (result == true) {
      _loadProfileAndStats();
    }
  }

  /// Today Overview cards grid styled identically to Dashboard task metric cards
  Widget _buildOverviewCardsGrid(ThemeData theme, bool isDark) {
    const workColor = Color(0xFF6C5CE7);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            children: [
              const Icon(Icons.insights_rounded, size: 16, color: workColor),
              const SizedBox(width: 6),
              Text(
                'OVERVIEW METRICS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: isDark ? const Color(0xFF94A3B8) : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                theme,
                isDark,
                title: 'Streak Counter',
                value: '$_currentStreak ${_currentStreak == 1 ? "Day" : "Days"}',
                iconEmoji: '🔥',
                accentColor: const Color(0xFFFF7675),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                theme,
                isDark,
                title: 'Time Scheduled',
                value: _totalScheduledMinutesToday >= 60
                    ? '${_totalScheduledMinutesToday ~/ 60}h ${_totalScheduledMinutesToday % 60}m'
                    : '${_totalScheduledMinutesToday}m',
                iconIcon: Icons.schedule_rounded,
                accentColor: workColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                theme,
                isDark,
                title: 'Completion Rate',
                value: '$_completionRate%',
                iconIcon: Icons.task_alt_rounded,
                accentColor: const Color(0xFF00D2D3),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                theme,
                isDark,
                title: 'Total Tasks',
                value: '$_totalTasks Active',
                iconIcon: Icons.checklist_rounded,
                accentColor: const Color(0xFF3B82F6),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    ThemeData theme,
    bool isDark, {
    required String title,
    required String value,
    String? iconEmoji,
    IconData? iconIcon,
    required Color accentColor,
  }) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? accentColor.withValues(alpha: 0.3)
              : Colors.grey.shade200,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: isDark ? 0.08 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: iconEmoji != null
                ? Text(iconEmoji, style: const TextStyle(fontSize: 17))
                : Icon(iconIcon, color: accentColor, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                    color: isDark ? const Color(0xFFF1F5F9) : theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Categorized Settings Menu Container with distinct sections
  Widget _buildGroupedSettingsMenu(BuildContext context, ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(theme, isDark, label: 'PERSONAL & ACCOUNT', icon: Icons.person_pin_rounded),
        const SizedBox(height: 8),
        _buildSettingsCardContainer(
          isDark: isDark,
          children: [
            _buildMenuTile(
              theme,
              isDark,
              icon: Icons.person_outline_rounded,
              iconColor: const Color(0xFF6C5CE7),
              title: 'Profile Settings',
              subtitle: 'Edit name, designation, age & hobbies',
              onTap: _openEditProfileScreen,
            ),
            _buildMenuDivider(theme, isDark),
            _buildMenuTile(
              theme,
              isDark,
              icon: Icons.cloud_sync_rounded,
              iconColor: const Color(0xFF3B82F6),
              title: 'Account & Cloud Sync',
              subtitle: 'Manage Google account & Backup sync',
              trailingBadge: widget.authService?.isSignedIn == true ? 'Synced' : 'Offline',
              badgeColor: widget.authService?.isSignedIn == true ? const Color(0xFF00D2D3) : Colors.grey,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => AccountSyncScreen(
                      authService: widget.authService,
                      routineRepository: widget.routineRepository,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 20),

        _buildSectionHeader(theme, isDark, label: 'PREFERENCES & INTELLIGENCE', icon: Icons.auto_awesome_rounded),
        const SizedBox(height: 8),
        _buildSettingsCardContainer(
          isDark: isDark,
          children: [
            ListenableBuilder(
              listenable: NotificationSettingsController.instance,
              builder: (context, _) {
                return _buildMenuTile(
                  theme,
                  isDark,
                  icon: Icons.notifications_active_outlined,
                  iconColor: const Color(0xFFFF7675),
                  title: 'Notifications',
                  subtitle: NotificationSettingsController.instance.summaryText,
                  onTap: () => _showNotificationSettingsModalSheet(context),
                );
              },
            ),
            _buildMenuDivider(theme, isDark),
            ListenableBuilder(
              listenable: ThemeController.instance,
              builder: (context, _) {
                return _buildMenuTile(
                  theme,
                  isDark,
                  icon: Icons.palette_outlined,
                  iconColor: const Color(0xFF00D2D3),
                  title: 'Appearance & Theme',
                  subtitle: '${ThemeController.instance.themeModeName} · Customise styling',
                  trailingBadge: ThemeController.instance.themeModeName,
                  badgeColor: const Color(0xFF00D2D3),
                  onTap: () => _showThemeSelectionModalSheet(context),
                );
              },
            ),
            _buildMenuDivider(theme, isDark),
            ListenableBuilder(
              listenable: ThemeController.instance,
              builder: (context, _) {
                final primaryColor = ThemeController.instance.seedColor;
                return _buildMenuTile(
                  theme,
                  isDark,
                  icon: Icons.psychology_rounded,
                  iconColor: primaryColor,
                  title: 'On-Device AI & Storage',
                  subtitle: 'Manage Qwen2.5-0.5B model (390 MB) & cache',
                  trailingBadge: 'Offline AI',
                  badgeColor: primaryColor,
                  onTap: () {
                    OfflineModelDownloadDialog.show(context);
                  },
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 20),

        _buildSectionHeader(theme, isDark, label: 'ABOUT & INFORMATION', icon: Icons.info_outline_rounded),
        const SizedBox(height: 8),
        _buildSettingsCardContainer(
          isDark: isDark,
          children: [
            _buildMenuTile(
              theme,
              isDark,
              icon: Icons.info_rounded,
              iconColor: const Color(0xFFA855F7),
              title: 'About Nooktime',
              subtitle: 'v3.0.5 · Personal Companion',
              trailingBadge: 'v3.0.5',
              badgeColor: const Color(0xFFA855F7),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => const AboutNooktimeScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(ThemeData theme, bool isDark, {required String label, required IconData icon}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: isDark ? const Color(0xFF94A3B8) : theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: isDark ? const Color(0xFF94A3B8) : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCardContainer({required bool isDark, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  void _showThemeSelectionModalSheet(BuildContext context) {
    AppearanceThemeBottomSheet.show(context);
  }

  void _showNotificationSettingsModalSheet(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const workColor = Color(0xFF6C5CE7);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return ListenableBuilder(
          listenable: NotificationSettingsController.instance,
          builder: (context, _) {
            final routineEnabled = NotificationSettingsController.instance.routineNotificationsEnabled;
            final reminderEnabled = NotificationSettingsController.instance.reminderNotificationsEnabled;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF475569) : Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        'Notification Preferences',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: routineEnabled,
                      activeTrackColor: workColor,
                      secondary: const Icon(Icons.repeat_rounded, color: workColor),
                      title: const Text('Routine Task Notifications', style: TextStyle(fontWeight: FontWeight.w600)),
                      onChanged: (val) {
                        HapticFeedback.lightImpact();
                        NotificationSettingsController.instance.setRoutineNotificationsEnabled(val);
                      },
                    ),
                    SwitchListTile(
                      value: reminderEnabled,
                      activeTrackColor: const Color(0xFF3B82F6),
                      secondary: const Icon(Icons.event_note_rounded, color: Color(0xFF3B82F6)),
                      title: const Text('Reminder Task Notifications', style: TextStyle(fontWeight: FontWeight.w600)),
                      onChanged: (val) {
                        HapticFeedback.lightImpact();
                        NotificationSettingsController.instance.setReminderNotificationsEnabled(val);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMenuTile(
    ThemeData theme,
    bool isDark, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    String? trailingBadge,
    Color? badgeColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14.5,
          color: isDark ? const Color(0xFFF1F5F9) : theme.colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 11.5,
          color: isDark ? const Color(0xFF94A3B8) : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingBadge != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (badgeColor ?? iconColor).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: (badgeColor ?? iconColor).withValues(alpha: 0.3)),
              ),
              child: Text(
                trailingBadge,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: badgeColor ?? iconColor,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Icon(
            Icons.chevron_right_rounded,
            color: isDark ? const Color(0xFF64748B) : Colors.grey.shade400,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuDivider(ThemeData theme, bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 64,
      endIndent: 16,
      color: isDark
          ? const Color(0xFF334155).withValues(alpha: 0.5)
          : Colors.grey.shade200,
    );
  }
}
