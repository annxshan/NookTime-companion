import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/services/database_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/notification_settings_controller.dart';
import 'core/theme/theme_controller.dart';
import 'core/widgets/floating_nav_bar.dart';
import 'features/calendar_sync/repositories/sync_repository.dart';
import 'features/calendar_sync/services/auth_service.dart';
import 'features/calendar_sync/services/google_calendar_service.dart';
import 'features/daily_routine/data/routine_repository.dart';
import 'features/daily_routine/presentation/dashboard_screen.dart';
import 'features/reminders/presentation/reminder_screen.dart';
import 'features/splash/presentation/splash_screen.dart';
import 'features/time_analytics/presentation/analytics_controller.dart';
import 'features/time_analytics/presentation/analytics_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'features/profile/presentation/profile_screen.dart';
import 'features/sync/services/cloud_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Low latency: Tune engine image cache RAM limit
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024;
  PaintingBinding.instance.imageCache.maximumSize = 100;

  // Initialize Firebase Core
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init notice: $e');
  }

  // Initialize controllers
  await ThemeController.instance.init();
  await NotificationSettingsController.instance.init();

  // Initialize services
  final databaseService = DatabaseService();
  await databaseService.database;

  final notificationService = NotificationService();
  await notificationService.initialize();

  final cloudSyncService = CloudSyncService();

  final authService = AuthService(
    databaseService: databaseService,
    cloudSyncService: cloudSyncService,
  );
  await authService.initialize(
    serverClientId:
        '338169249906-c4i5m8lp2aij6je8n923j2om9qt1g7n7.apps.googleusercontent.com',
  );
  await authService.initSilentSignIn();

  final googleCalendarService = GoogleCalendarService(authService: authService);

  // Initialize sync repository
  final syncRepository = SyncRepository(
    databaseService: databaseService,
    googleCalendarService: googleCalendarService,
  );

  // Initialize routine repository
  final routineRepository = RoutineRepository(
    databaseService: databaseService,
    notificationService: notificationService,
    googleCalendarService: googleCalendarService,
    authService: authService,
    cloudSyncService: cloudSyncService,
  );

  // Initialize analytics controller
  final analyticsController = AnalyticsController(databaseService: databaseService);

  runApp(NooktimeApp(
    routineRepository: routineRepository,
    authService: authService,
    syncRepository: syncRepository,
    analyticsController: analyticsController,
  ));
}

/// Root widget for the Nooktime application.
class NooktimeApp extends StatelessWidget {
  final RoutineRepository routineRepository;
  final AuthService authService;
  final SyncRepository syncRepository;
  final AnalyticsController analyticsController;

  const NooktimeApp({
    super.key,
    required this.routineRepository,
    required this.authService,
    required this.syncRepository,
    required this.analyticsController,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'Nooktime',
          debugShowCheckedModeBanner: false,
          theme: ThemeController.instance.lightTheme,
          darkTheme: ThemeController.instance.darkTheme,
          themeMode: ThemeController.instance.themeMode,
          builder: (context, child) {
            if (!kIsWeb) return child!;

            return Container(
              color: const Color(0xFF0B0F17),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: ClipRect(child: child),
                ),
              ),
            );
          },
          home: SplashScreen(
            child: MainNavigationContainer(
              routineRepository: routineRepository,
              authService: authService,
              syncRepository: syncRepository,
              analyticsController: analyticsController,
            ),
          ),
        );
      },
    );
  }
}

/// Navigation shell wrapping bottom navigation tabs.
class MainNavigationContainer extends StatefulWidget {
  final RoutineRepository routineRepository;
  final AuthService authService;
  final SyncRepository syncRepository;
  final AnalyticsController analyticsController;

  const MainNavigationContainer({
    super.key,
    required this.routineRepository,
    required this.authService,
    required this.syncRepository,
    required this.analyticsController,
  });

  @override
  State<MainNavigationContainer> createState() =>
      _MainNavigationContainerState();
}

class _MainNavigationContainerState extends State<MainNavigationContainer> {
  int _currentIndex = 0;
  late final PageController _pageController;
  List<Widget>? _pagesCache;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToPage(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  List<Widget> get _pages => _pagesCache ??= [
        DashboardScreen(
          routineRepository: widget.routineRepository,
          authService: widget.authService,
          syncRepository: widget.syncRepository,
          onNavigateToSettings: () => _navigateToPage(3),
          onNavigateToReminders: () => _navigateToPage(1),
        ),
        ReminderScreen(
          routineRepository: widget.routineRepository,
          authService: widget.authService,
          syncRepository: widget.syncRepository,
          onNavigateToSettings: () => _navigateToPage(3),
        ),
        AnalyticsScreen(
          controller: widget.analyticsController,
        ),
        ProfileScreen(
          authService: widget.authService,
          syncRepository: widget.syncRepository,
          routineRepository: widget.routineRepository,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              if (_currentIndex != index) {
                setState(() {
                  _currentIndex = index;
                });
              }
            },
            physics: const _SlowSwipePagePhysics(),
            children: _pages.map((p) => RepaintBoundary(child: p)).toList(),
          ),
          ListenableBuilder(
            listenable: widget.authService,
            builder: (context, _) {
              final photoUrl = widget.authService.currentUser?.photoUrl ??
                  widget.authService.cachedPhotoUrl;
              return FloatingNavBar(
                currentIndex: _currentIndex,
                photoUrl: photoUrl,
                onTap: (index) {
                  _navigateToPage(index);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Custom [PageScrollPhysics] that demands a more deliberate horizontal swipe
/// before committing to a page change. Raises the minimum fling velocity and
/// drag distance thresholds so casual/accidental touches don't flip screens.
class _SlowSwipePagePhysics extends PageScrollPhysics {
  const _SlowSwipePagePhysics() : super(parent: const ClampingScrollPhysics());

  @override
  _SlowSwipePagePhysics applyTo(ScrollPhysics? ancestor) =>
      const _SlowSwipePagePhysics();

  /// Raise the fling velocity threshold — user must swipe faster/further
  /// than 1200 px/s (default ~800) before a page flip is committed.
  @override
  double get minFlingVelocity => 1200.0;

  /// Require at least 40 % of the viewport width as a drag distance
  /// before the page snaps over (default is ~50 % but with low velocity).
  @override
  double get dragStartDistanceMotionThreshold => 3.5;
}
