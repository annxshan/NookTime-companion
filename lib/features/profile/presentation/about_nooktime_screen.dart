import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';

/// Detailed About Nooktime Screen.
/// Provides a comprehensive user manual, architecture breakdown, feature advantages,
/// AI Engine specs, and Lead Developer information.
class AboutNooktimeScreen extends StatelessWidget {
  const AboutNooktimeScreen({super.key});

  Future<void> _launchUrlOrCopy(BuildContext context, String urlString, String label) async {
    HapticFeedback.lightImpact();
    await Clipboard.setData(ClipboardData(text: urlString));
    if (context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF00D2D3), size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text('$label copied to clipboard!')),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final workColor = AppTheme.categoryColor('work');

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text(
            'About Nooktime',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
          ),
          centerTitle: true,
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          bottom: TabBar(
            isScrollable: true,
            labelColor: workColor,
            unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
            indicatorColor: workColor,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'AI Engine'),
              Tab(text: 'Features'),
              Tab(text: 'User Manual'),
              Tab(text: 'Developer'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildOverviewTab(context, theme, isDark, workColor),
            _buildAiEngineTab(theme, isDark, workColor),
            _buildFeaturesTab(theme, isDark, workColor),
            _buildUserManualTab(theme, isDark, workColor),
            _buildDeveloperTab(context, theme, isDark, workColor),
          ],
        ),
      ),
    );
  }

  // ── 1. Overview Tab ────────────────────────────────────────────────────────
  Widget _buildOverviewTab(BuildContext context, ThemeData theme, bool isDark, Color workColor) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // App Hero Header Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: isDark
                  ? const [Color(0xFF1E1845), Color(0xFF1A2230)]
                  : [theme.cardColor, theme.colorScheme.primaryContainer.withAlpha(120)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: workColor.withAlpha(60),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  isDark ? 'assets/icon_dark.png' : 'assets/icon_light.png',
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Nooktime',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      letterSpacing: -0.5,
                      color: isDark ? const Color(0xFFF1F5F9) : theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Personal AI Routine & Cloud Productivity Companion',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: workColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Nooktime is an intelligent offline-first AI routine planner featuring Cloud Firestore Database Dual-Sync, Firebase Authentication security bridging, dual-engine AI (Groq Llama 3.3 + On-Device Qwen 0.5B), interactive Google Calendar integration, and local pattern learning.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  height: 1.5,
                  color: isDark ? const Color(0xFF94A3B8) : theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Core Advantages
        _buildSectionHeader(theme, isDark, 'CORE ADVANTAGES', Icons.verified_rounded, workColor),
        const SizedBox(height: 12),

        _buildAdvantageCard(
          theme,
          isDark,
          icon: Icons.psychology_rounded,
          iconColor: const Color(0xFFFFAA00),
          title: 'On-Device Qwen2.5-0.5B AI Engine',
          description:
              'Bundles a 390 MB GGUF LLM engine directly on disk for 100% complete offline routine generation without internet or API keys!',
        ),
        const SizedBox(height: 12),

        _buildAdvantageCard(
          theme,
          isDark,
          icon: Icons.calendar_month_rounded,
          iconColor: const Color(0xFF00D2D3),
          title: 'Google Calendar Interactive Reminders View',
          description:
              'Full monthly calendar dropdown with event indicator dots, date selection filtering, and 2-way Google Calendar event sync.',
        ),
        const SizedBox(height: 12),

        _buildAdvantageCard(
          theme,
          isDark,
          icon: Icons.auto_awesome_rounded,
          iconColor: workColor,
          title: 'Continuous Local AI Pattern Learning',
          description:
              'Automatically distills and vectorizes scheduling habits every time ANY engine (Groq, Qwen, Gemini, Local) completes a routine.',
        ),
        const SizedBox(height: 12),

        _buildAdvantageCard(
          theme,
          isDark,
          icon: Icons.cloud_sync_rounded,
          iconColor: const Color(0xFF10B981),
          title: 'Cloud Firestore Database Dual-Sync',
          description:
              'Dual-writes local SQLite actions to Cloud Firestore with isolated Firebase Auth security rules. Features two-way pull-to-refresh sync, real-time cloud deletion, and seamless multi-device restoration!',
        ),
      ],
    );
  }

  // ── 2. AI Engine Tab ───────────────────────────────────────────────────────
  Widget _buildAiEngineTab(ThemeData theme, bool isDark, Color workColor) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionHeader(theme, isDark, 'AI ARCHITECTURE & SPECIFICATIONS', Icons.memory_rounded, workColor),
        const SizedBox(height: 14),

        _buildFeatureDetailCard(
          theme,
          isDark,
          badgeText: 'HYBRID AI SYSTEM',
          badgeColor: workColor,
          title: '1. Groq Cloud AI Model Pipeline',
          body:
              'Queries high-speed Groq AI models (groq/compound-mini, qwen/qwen3.6-27b, openai/gpt-oss-20b) to transform raw natural language prompts (e.g. "Exam next week, study 3 hours and keep 1 hour gym") into structured, non-overlapping daily schedules.',
        ),
        const SizedBox(height: 14),

        _buildFeatureDetailCard(
          theme,
          isDark,
          badgeText: 'ON-DEVICE INTELLIGENCE',
          badgeColor: const Color(0xFFFF6B00),
          title: '2. Local AI Distillation Service',
          body:
              'Captures Groq responses in non-blocking background threads, extracts time anchors (e.g. 8:30am to 1pm), tokenizes prompt structures, and stores pattern signatures into local storage. When offline, it synthesizes matching schedules locally with 0ms network latency.',
        ),
        const SizedBox(height: 14),

        _buildFeatureDetailCard(
          theme,
          isDark,
          badgeText: 'CONFLICT RESOLUTION',
          badgeColor: const Color(0xFF3B82F6),
          title: '3. Local Schedule Engine Heuristics',
          body:
              'Evaluates timeline slots chronologically, computes exact duration bounds, resolves overlapping tasks automatically, and aligns schedule items with preset goal archetypes (Exam Prep, Fitness, Deep Work, Healthy Lifestyle).',
        ),
        const SizedBox(height: 14),

        _buildFeatureDetailCard(
          theme,
          isDark,
          badgeText: 'SMART FALLBACK',
          badgeColor: const Color(0xFF00A884),
          title: '4. Offline Fallback & UI Badge',
          body:
              'If network connectivity fails or Groq quota limits are reached, Nooktime seamlessly switches to the On-Device Learned AI Engine and tags the preview with a gold badge: "⚡ Generated using On-Device Learned AI Engine".',
        ),
      ],
    );
  }

  // ── 3. Features Tab ────────────────────────────────────────────────────────
  Widget _buildFeaturesTab(ThemeData theme, bool isDark, Color workColor) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionHeader(theme, isDark, 'COMPLETE FEATURE BREAKDOWN', Icons.widgets_rounded, workColor),
        const SizedBox(height: 14),

        _buildBulletFeatureCard(
          theme,
          isDark,
          icon: Icons.calendar_view_week_rounded,
          title: '7-Day Multi-Day Routine Checklist',
          bullets: [
            'Each day of the week (Monday through Sunday) maintains an independent task list.',
            'Filter schedule view by day with the horizontal weekday selector bar.',
            'Task completion state is strictly isolated to today, preventing cross-day bleed.',
            'Automatic midnight reset clears checklist completions so Monday task cycle restarts cleanly.',
          ],
        ),
        const SizedBox(height: 14),

        _buildBulletFeatureCard(
          theme,
          isDark,
          icon: Icons.local_fire_department_rounded,
          title: 'Streak & Gamification Engine',
          bullets: [
            'Evaluates tasks scheduled specifically for today\'s active weekday.',
            'Increments streak count upon completing all active daily routines.',
            'Triggers interactive celebration dialogs with haptic feedback upon achieving milestones.',
            'Displays real-time completion percentage (%) and total scheduled time in Profile Overview.',
          ],
        ),
        const SizedBox(height: 14),

        _buildBulletFeatureCard(
          theme,
          isDark,
          icon: Icons.sync_rounded,
          title: 'Firestore & SQLite Dual-Sync',
          bullets: [
            'Dual-write operations for task creation, update, deletion, and completion toggle.',
            'Google Sign-In integration for seamless account authentication.',
            'Auto-fetches and hydrates local SQLite database upon user login or session restore.',
            'Non-blocking try-catch error resilience preserves 100% offline capability.',
          ],
        ),
        const SizedBox(height: 14),

        _buildBulletFeatureCard(
          theme,
          isDark,
          icon: Icons.alarm_rounded,
          title: 'Smart Notification Controller',
          bullets: [
            'Daily recurring alarms for scheduled routine tasks.',
            'Exact date & time alerts for one-off reminder items.',
            'Toggle routine vs reminder notification preferences independently in Profile Settings.',
          ],
        ),
      ],
    );
  }

  // ── 4. User Manual Tab ─────────────────────────────────────────────────────
  Widget _buildUserManualTab(ThemeData theme, bool isDark, Color workColor) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionHeader(theme, isDark, 'NOOKTIME USER MANUAL & TIPS', Icons.menu_book_rounded, workColor),
        const SizedBox(height: 14),

        _buildManualStepTile(
          theme,
          isDark,
          stepNumber: '1',
          title: 'How to Generate AI Schedules',
          description:
              'Tap the floating Sparkle AI button on the Routine screen. Type a prompt like "College 8:30am to 1pm, study Flutter 2 hours, gym 6pm" or select a preset goal chip. Tap "Generate Schedule with AI" to preview and apply.',
        ),
        const SizedBox(height: 12),

        _buildManualStepTile(
          theme,
          isDark,
          stepNumber: '2',
          title: 'Managing Specific Days of the Week',
          description:
              'Use the top weekday selector (M, T, W, T, F, S, S) to view or schedule tasks for specific days. When creating or editing a task, select which repeat days it should activate on.',
        ),
        const SizedBox(height: 12),

        _buildManualStepTile(
          theme,
          isDark,
          stepNumber: '3',
          title: 'Completing Tasks & Maintaining Streaks',
          description:
              'Tap task checkboxes on today\'s checklist to mark items complete. Complete 100% of today\'s scheduled tasks to increment your daily streak counter.',
        ),
        const SizedBox(height: 12),

        _buildManualStepTile(
          theme,
          isDark,
          stepNumber: '4',
          title: 'Deleting & Undoing Routines',
          description:
              'Swipe left or tap the delete option on a task card. A 3-second floating SnackBar notification appears at the bottom with an UNDO button to instantly restore deleted tasks.',
        ),
        const SizedBox(height: 12),

        _buildManualStepTile(
          theme,
          isDark,
          stepNumber: '5',
          title: 'Cloud Backup & Syncing Devices',
          description:
              'Go to Profile -> Account & Sign-In -> Connect your Google Account. All local routines will automatically sync to Cloud Firestore and restore when logging into a new device.',
        ),
      ],
    );
  }

  // ── 5. Developer Tab ───────────────────────────────────────────────────────
  Widget _buildDeveloperTab(BuildContext context, ThemeData theme, bool isDark, Color workColor) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionHeader(theme, isDark, 'DEVELOPER & CREATOR INFO', Icons.person_pin_rounded, workColor),
        const SizedBox(height: 14),

        _buildDeveloperOverviewCard(context, theme, isDark, workColor),
        const SizedBox(height: 20),

        _buildSectionHeader(theme, isDark, 'GET IN TOUCH & CONNECT', Icons.connect_without_contact_rounded, workColor),
        const SizedBox(height: 12),

        // Contact Tiles with URL launcher & Copy support
        _buildContactTile(
          theme,
          isDark,
          icon: Icons.email_rounded,
          iconColor: const Color(0xFFFF4757),
          title: 'Gmail / Email',
          subtitle: 'choudhuryannneshan@gmail.com',
          actionLabel: 'Send Email',
          onTap: () => _launchUrlOrCopy(context, 'mailto:choudhuryannneshan@gmail.com', 'Gmail'),
        ),
        const SizedBox(height: 10),

        _buildContactTile(
          theme,
          isDark,
          icon: Icons.business_center_rounded,
          iconColor: const Color(0xFF0A66C2),
          title: 'LinkedIn',
          subtitle: 'linkedin.com/in/annxshan',
          actionLabel: 'Open Profile',
          onTap: () => _launchUrlOrCopy(context, 'https://linkedin.com/in/annxshan', 'LinkedIn'),
        ),
        const SizedBox(height: 10),

        _buildContactTile(
          theme,
          isDark,
          icon: Icons.code_rounded,
          iconColor: isDark ? Colors.white : Colors.black,
          title: 'GitHub',
          subtitle: 'github.com/annxshan',
          actionLabel: 'Open GitHub',
          onTap: () => _launchUrlOrCopy(context, 'https://github.com/annxshan', 'GitHub'),
        ),
        const SizedBox(height: 24),

        // App Footer Info
        Center(
          child: Column(
            children: [
              Text(
                'Nooktime Routine Companion',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Crafted with love by Anneshan Choudhury',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: workColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Helper Widgets ─────────────────────────────────────────────────────────

  Widget _buildDeveloperOverviewCard(BuildContext context, ThemeData theme, bool isDark, Color workColor) {
    final cardBg = isDark ? theme.cardColor : theme.colorScheme.surface;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        DefaultTabController.of(context).animateTo(4);
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: workColor.withAlpha(60),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 15 : 6),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [workColor, const Color(0xFF3B82F6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: workColor.withAlpha(80),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: CircleAvatar(
                      backgroundColor: Color(0xFF161228),
                      child: Text(
                        'AC',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Anneshan Choudhury',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: isDark ? const Color(0xFFF1F5F9) : theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Lead AI & Flutter Mobile Engineer',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: workColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Creator of Nooktime Routine Companion',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? const Color(0xFF94A3B8) : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? const Color(0xFF94A3B8) : theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactTile(
    ThemeData theme,
    bool isDark, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    String actionLabel = 'Open',
    required VoidCallback onTap,
  }) {
    final cardBg = isDark ? theme.cardColor : theme.colorScheme.surface;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? iconColor.withAlpha(45)
              : theme.colorScheme.outlineVariant.withAlpha(100),
          width: 1.2,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: isDark ? const Color(0xFFF1F5F9) : theme.colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 12,
            color: isDark ? const Color(0xFF94A3B8) : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: iconColor.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.open_in_new_rounded, size: 12, color: iconColor),
              const SizedBox(width: 4),
              Text(
                actionLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: iconColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, bool isDark, String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: isDark ? const Color(0xFF94A3B8) : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildAdvantageCard(
    ThemeData theme,
    bool isDark, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    final cardBg = isDark ? theme.cardColor : theme.colorScheme.surface;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? iconColor.withAlpha(45)
              : theme.colorScheme.outlineVariant.withAlpha(100),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 15 : 6),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: isDark ? const Color(0xFFF1F5F9) : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    height: 1.4,
                    color: isDark ? const Color(0xFF94A3B8) : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureDetailCard(
    ThemeData theme,
    bool isDark, {
    required String badgeText,
    required Color badgeColor,
    required String title,
    required String body,
  }) {
    final cardBg = isDark ? theme.cardColor : theme.colorScheme.surface;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? badgeColor.withAlpha(45)
              : theme.colorScheme.outlineVariant.withAlpha(100),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: badgeColor.withAlpha(80)),
            ),
            child: Text(
              badgeText,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: badgeColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: isDark ? const Color(0xFFF1F5F9) : theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              height: 1.45,
              color: isDark ? const Color(0xFF94A3B8) : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletFeatureCard(
    ThemeData theme,
    bool isDark, {
    required IconData icon,
    required String title,
    required List<String> bullets,
  }) {
    final cardBg = isDark ? theme.cardColor : theme.colorScheme.surface;
    final workColor = AppTheme.categoryColor('work');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? workColor.withAlpha(40)
              : theme.colorScheme.outlineVariant.withAlpha(100),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: workColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: isDark ? const Color(0xFFF1F5F9) : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...bullets.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(color: workColor, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Text(
                      b,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        height: 1.4,
                        color: isDark ? const Color(0xFF94A3B8) : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualStepTile(
    ThemeData theme,
    bool isDark, {
    required String stepNumber,
    required String title,
    required String description,
  }) {
    final cardBg = isDark ? theme.cardColor : theme.colorScheme.surface;
    final workColor = AppTheme.categoryColor('work');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? workColor.withAlpha(35)
              : theme.colorScheme.outlineVariant.withAlpha(100),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: workColor.withAlpha(30),
              shape: BoxShape.circle,
              border: Border.all(color: workColor),
            ),
            child: Center(
              child: Text(
                stepNumber,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: workColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: isDark ? const Color(0xFFF1F5F9) : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    height: 1.45,
                    color: isDark ? const Color(0xFF94A3B8) : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
