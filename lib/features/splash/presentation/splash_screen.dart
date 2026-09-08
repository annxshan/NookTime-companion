import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../core/theme/app_theme.dart';

/// Animated splash screen featuring the Lottie triangle animation, branding,
/// and smooth transition to the main app navigation shell.
class SplashScreen extends StatefulWidget {
  final Widget child;
  final Duration displayDuration;

  const SplashScreen({
    super.key,
    required this.child,
    this.displayDuration = const Duration(milliseconds: 2600),
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _startSplashScreenTimer();
  }

  void _startSplashScreenTimer() async {
    await Future.delayed(widget.displayDuration);
    if (mounted) {
      _fadeController.forward().then((_) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                widget.child,
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Lottie Animation Container with Glassmorphic Shadow
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.categoryColor('work').withAlpha(40),
                    blurRadius: 40,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Lottie.asset(
                'assets/lottie/splash_animation.json',
                width: 200,
                height: 200,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.access_time_filled_rounded,
                    size: 80,
                    color: Color(0xFF6C5CE7),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),

            // App Title
            ShaderMask(
              shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(
                Rect.fromLTWH(0, 0, bounds.width, bounds.height),
              ),
              child: Text(
                'Nooktime',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -1.0,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Subtitle / Tagline
            Text(
              'Routine & Focus Companion',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 48),

            // Minimal Progress Dots
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.categoryColor('work').withAlpha(180),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
