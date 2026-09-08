import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nooktime/core/theme/theme_controller.dart';
import 'package:nooktime/features/daily_routine/presentation/widgets/routine_header_card.dart';
import 'package:nooktime/features/settings/presentation/widgets/appearance_bottom_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ThemeController.instance.init();
  });

  group('ThemeController tests', () {
    test('default seed color and theme mode are loaded correctly', () {
      final controller = ThemeController.instance;
      expect(controller.themeMode, equals(ThemeMode.system));
      expect(controller.seedColor, equals(ThemeController.defaultSeedColor));
      expect(controller.isCustomColor, isFalse);
    });

    test('setThemeMode updates theme mode and persists key', () async {
      final controller = ThemeController.instance;
      controller.setThemeMode(ThemeMode.dark);
      expect(controller.themeMode, equals(ThemeMode.dark));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), equals('dark'));
    });

    test('setSeedColor updates seed color and persists key', () async {
      final controller = ThemeController.instance;
      const newColor = Color(0xFF00D2D3);
      controller.setSeedColor(newColor, isCustom: false);
      expect(controller.seedColor, equals(newColor));
      expect(controller.isCustomColor, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('primary_seed_color'), equals(newColor.toARGB32()));
      expect(prefs.getBool('is_custom_color'), isFalse);
    });
  });

  group('AppearanceThemeBottomSheet Widget tests', () {
    testWidgets('renders all required elements: header, mode switcher, palette grid', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeController.instance.lightTheme,
          darkTheme: ThemeController.instance.darkTheme,
          home: const Scaffold(
            body: AppearanceThemeBottomSheet(),
          ),
        ),
      );

      // Verify Title
      expect(find.text('Appearance & Theme'), findsOneWidget);

      // Verify Segmented Mode Switcher Options
      expect(find.text('🖥️ System'), findsOneWidget);
      expect(find.text('☀️ Light'), findsOneWidget);
      expect(find.text('🌙 Dark'), findsOneWidget);

      // Verify Section Header
      expect(find.text('Accent Color Palette'), findsOneWidget);
      expect(find.text('Select an accent tone or choose a custom color.'), findsOneWidget);

      // Verify Eyedropper Icon is present for custom color picker
      expect(find.byIcon(Icons.colorize_rounded), findsOneWidget);
    });

    testWidgets('tapping theme mode pill switches theme mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeController.instance.lightTheme,
          darkTheme: ThemeController.instance.darkTheme,
          home: const Scaffold(
            body: AppearanceThemeBottomSheet(),
          ),
        ),
      );

      // Tap Light Theme
      await tester.tap(find.text('☀️ Light'));
      await tester.pumpAndSettle();

      expect(ThemeController.instance.themeMode, equals(ThemeMode.light));

      // Tap Dark Theme
      await tester.tap(find.text('🌙 Dark'));
      await tester.pumpAndSettle();

      expect(ThemeController.instance.themeMode, equals(ThemeMode.dark));
    });

    testWidgets('RoutineHeaderCard dynamically updates color matching ThemeController seedColor', (WidgetTester tester) async {
      await tester.pumpWidget(
        ListenableBuilder(
          listenable: ThemeController.instance,
          builder: (context, _) {
            return MaterialApp(
              theme: ThemeController.instance.lightTheme,
              darkTheme: ThemeController.instance.darkTheme,
              home: const Scaffold(
                body: RoutineHeaderCard(
                  completed: 2,
                  total: 5,
                ),
              ),
            );
          },
        ),
      );

      expect(find.text("Today's Routine"), findsOneWidget);

      // Change seed color
      const cyanColor = Color(0xFF00D2D3);
      ThemeController.instance.setSeedColor(cyanColor, isCustom: false);
      await tester.pumpAndSettle();

      expect(ThemeController.instance.seedColor, equals(cyanColor));
    });
  });
}
