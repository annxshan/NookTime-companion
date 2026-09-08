import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/streak_service.dart';

/// Compact 🔥 streak pill for the app bar.
/// Tapping opens a bottom sheet with streak stats and weekly dot tracker.
class StreakBadge extends StatefulWidget {
  final StreakService streakService;

  const StreakBadge({super.key, required this.streakService});

  @override
  State<StreakBadge> createState() => _StreakBadgeState();
}

class _StreakBadgeState extends State<StreakBadge> {
  late Future<int> _streakFuture;

  @override
  void initState() {
    super.initState();
    _streakFuture = widget.streakService.getCurrentStreak();
  }

  @override
  void didUpdateWidget(StreakBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streakService != widget.streakService) {
      _streakFuture = widget.streakService.getCurrentStreak();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _streakFuture,
      builder: (context, snapshot) {
        final streak = snapshot.data ?? 0;
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            _showStreakSheet(context);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B00), Color(0xFFFFB800)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: streak > 0
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFF6B00).withAlpha(80),
                        blurRadius: 8,
                        spreadRadius: 0,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔥', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(
                  '$streak',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showStreakSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StreakDetailSheet(streakService: widget.streakService),
    );
  }
}

// ── Streak Detail Bottom Sheet ─────────────────────────────────────────────────

class _StreakDetailSheet extends StatefulWidget {
  final StreakService streakService;
  const _StreakDetailSheet({required this.streakService});

  @override
  State<_StreakDetailSheet> createState() => _StreakDetailSheetState();
}

class _StreakDetailSheetState extends State<_StreakDetailSheet>
    with SingleTickerProviderStateMixin {
  int _current = 0;
  int _best = 0;
  late final AnimationController _flameCtrl;
  late final Animation<double> _flamePulse;

  @override
  void initState() {
    super.initState();
    _flameCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _flamePulse = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _flameCtrl, curve: Curves.easeInOut),
    );
    _loadStats();
  }

  Future<void> _loadStats() async {
    final current = await widget.streakService.getCurrentStreak();
    final best = await widget.streakService.getBestStreak();
    if (mounted) {
      setState(() {
        _current = current;
        _best = best;
      });
    }
  }

  @override
  void dispose() {
    _flameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: theme.colorScheme.outline.withAlpha(60),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Animated flame
            ScaleTransition(
              scale: _flamePulse,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFF6B00)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B00).withAlpha(100),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('🔥', style: TextStyle(fontSize: 36)),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Streak counts row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatChip(
                  label: 'Current Streak',
                  value: '$_current',
                  unit: _current == 1 ? 'day' : 'days',
                  color: const Color(0xFFFF6B00),
                ),
                Container(
                  width: 1,
                  height: 48,
                  color: theme.colorScheme.outline.withAlpha(60),
                ),
                _StatChip(
                  label: 'Best Streak',
                  value: '$_best',
                  unit: _best == 1 ? 'day' : 'days',
                  color: const Color(0xFFFFB800),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Weekly dot tracker header
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'This Week',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 7-day dot tracker (Mon–Sun)
            _WeeklyDotTracker(
              currentStreak: _current,
              today: now,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stat Chip ─────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -1,
                ),
              ),
              TextSpan(
                text: ' $unit',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Weekly Dot Tracker ────────────────────────────────────────────────────────

class _WeeklyDotTracker extends StatelessWidget {
  final int currentStreak;
  final DateTime today;

  const _WeeklyDotTracker({
    required this.currentStreak,
    required this.today,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Mon = 1 ... Sun = 7
    final weekday = today.weekday;
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final dayIndex = i + 1; // 1=Mon ... 7=Sun
        final daysAgoFromToday = weekday - dayIndex;
        final isToday = dayIndex == weekday;
        final isPast = dayIndex < weekday;
        final isFuture = dayIndex > weekday;

        bool isCompleted = false;
        if (!isFuture && currentStreak > 0) {
          isCompleted = daysAgoFromToday < currentStreak;
        }

        return Column(
          children: [
            AnimatedContainer(
              duration: Duration(milliseconds: 300 + (i * 50)),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isCompleted
                    ? const LinearGradient(
                        colors: [Color(0xFFFF6B00), Color(0xFFFFB800)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isCompleted
                    ? null
                    : isToday
                        ? theme.colorScheme.primaryContainer.withAlpha(120)
                        : theme.colorScheme.surfaceContainerHighest,
                border: isToday && !isCompleted
                    ? Border.all(
                        color: const Color(0xFFFF6B00).withAlpha(160),
                        width: 2,
                      )
                    : null,
                boxShadow: isCompleted
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFF6B00).withAlpha(60),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
              child: Center(
                child: isCompleted
                    ? const Text('🔥', style: TextStyle(fontSize: 16))
                    : Text(
                        days[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isToday
                              ? theme.colorScheme.primary
                              : isPast
                                  ? theme.colorScheme.onSurfaceVariant
                                      .withAlpha(100)
                                  : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              days[i],
              style: TextStyle(
                fontSize: 10,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                color: isToday
                    ? const Color(0xFFFF6B00)
                    : theme.colorScheme.onSurfaceVariant.withAlpha(120),
              ),
            ),
          ],
        );
      }),
    );
  }
}
