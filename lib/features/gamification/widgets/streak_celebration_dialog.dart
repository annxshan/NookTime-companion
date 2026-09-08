import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Duolingo-style celebration dialog shown when the user completes all tasks.
///
/// Usage:
/// ```dart
/// await StreakCelebrationDialog.show(context, streakCount: 5);
/// ```
class StreakCelebrationDialog extends StatefulWidget {
  final int streakCount;

  const StreakCelebrationDialog({super.key, required this.streakCount});

  /// Shows the celebration dialog and returns after dismissal.
  static Future<void> show(BuildContext context, {required int streakCount}) {
    HapticFeedback.heavyImpact();
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withAlpha(140),
      builder: (_) => StreakCelebrationDialog(streakCount: streakCount),
    );
  }

  @override
  State<StreakCelebrationDialog> createState() =>
      _StreakCelebrationDialogState();
}

class _StreakCelebrationDialogState extends State<StreakCelebrationDialog>
    with TickerProviderStateMixin {
  late final AnimationController _bounceCtrl;
  late final AnimationController _glowCtrl;
  late final AnimationController _fadeCtrl;

  late final Animation<double> _bounceScale;
  late final Animation<double> _glowRadius;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeIn = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _bounceScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 45),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 0.9), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.05), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 10),
    ]).animate(CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeOut));

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _glowRadius = Tween<double>(begin: 12, end: 32).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );

    _fadeCtrl.forward();
    _bounceCtrl.forward();
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    _glowCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNewStreak = widget.streakCount == 1;
    final heading = isNewStreak ? '1 Day Streak Started!' : 'Streak Extended!';

    return FadeTransition(
      opacity: _fadeIn,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: const Color(0xFFFF6B00).withAlpha(60),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B00).withAlpha(40),
                blurRadius: 40,
                spreadRadius: 8,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated glowing flame
                AnimatedBuilder(
                  animation: _glowRadius,
                  builder: (_, child) => Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFF6B00)],
                        stops: [0.3, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6B00).withAlpha(120),
                          blurRadius: _glowRadius.value,
                          spreadRadius: _glowRadius.value * 0.3,
                        ),
                      ],
                    ),
                    child: child,
                  ),
                  child: ScaleTransition(
                    scale: _bounceScale,
                    child: const Center(
                      child: Text('🔥', style: TextStyle(fontSize: 44)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Streak day badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B00), Color(0xFFFFB800)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${widget.streakCount} Day${widget.streakCount == 1 ? '' : 's'} 🔥',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Heading
                Text(
                  heading,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 10),

                // Subtitle
                Text(
                  'You completed 100% of your routine today. Keep the momentum going!',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),

                // Continue button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B00),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
