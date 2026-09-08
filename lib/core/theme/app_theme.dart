import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Nooktime's centralised theme system.
///
/// Palette (Dark OLED / Obsidian):
///   Background  : #0F141C  Deep Slate / Obsidian
///   Surface     : #1A2230  Dark Navy Card
///   Border      : #2A364F  Muted Blue-Grey
///   Primary     : #6C5CE7  Electric Indigo / Violet
///   Secondary   : #00D2D3  Vibrant Cyan / Teal
///   Tertiary    : #FD79A8  Soft Coral / Rose
///   Warning     : #FFAA00  Warm Amber
class AppTheme {
  AppTheme._();

  // ── Colour constants ────────────────────────────────────────────────────────

  static const Color _bgDark = Color(0xFF0F141C);
  static const Color _surfaceDark = Color(0xFF1A2230);
  static const Color _borderDark = Color(0xFF2A364F);
  static const Color _primary = Color(0xFF6C5CE7);
  static const Color _secondary = Color(0xFF00D2D3);
  static const Color _tertiary = Color(0xFFFD79A8);
  static const Color _warning = Color(0xFFFFAA00);
  static const Color _onPrimary = Color(0xFFFFFFFF);
  static const Color _onSurface = Color(0xFFE8EDF5);
  static const Color _onSurfaceVariant = Color(0xFF8A9BBF);

  static const Color _bgLight = Color(0xFFF3F0FF);
  static const Color _surfaceLight = Color(0xFFFAF8FF);
  static const Color _borderLight = Color(0xFFDDD6FE);
  static const Color _textLight = Color(0xFF1E1B4B);
  static const Color _subTextLight = Color(0xFF4C1D95);
  static const Color _primaryLight = Color(0xFF6C5CE7);

  // ── Text Theme ──────────────────────────────────────────────────────────────

  static TextTheme _buildTextTheme(Color baseColor) {
    return GoogleFonts.interTextTheme(
      TextTheme(
        displayLarge: TextStyle(
            color: baseColor, fontWeight: FontWeight.w700, letterSpacing: -1.5),
        displayMedium: TextStyle(
            color: baseColor, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        displaySmall: TextStyle(
            color: baseColor, fontWeight: FontWeight.w600, letterSpacing: -0.5),
        headlineLarge: TextStyle(
            color: baseColor, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        headlineMedium:
            TextStyle(color: baseColor, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(
            color: baseColor, fontWeight: FontWeight.w600, letterSpacing: 0.15),
        titleLarge: TextStyle(
            color: baseColor, fontWeight: FontWeight.w700, letterSpacing: 0),
        titleMedium: TextStyle(
            color: baseColor, fontWeight: FontWeight.w600, letterSpacing: 0.15),
        titleSmall: TextStyle(
            color: baseColor, fontWeight: FontWeight.w500, letterSpacing: 0.1),
        bodyLarge:
            TextStyle(color: baseColor, fontWeight: FontWeight.w400, height: 1.5),
        bodyMedium:
            TextStyle(color: baseColor, fontWeight: FontWeight.w400, height: 1.5),
        bodySmall:
            TextStyle(color: baseColor.withAlpha(180), fontWeight: FontWeight.w400),
        labelLarge: TextStyle(
            color: baseColor, fontWeight: FontWeight.w600, letterSpacing: 0.1),
        labelMedium: TextStyle(
            color: baseColor, fontWeight: FontWeight.w500, letterSpacing: 0.5),
        labelSmall: TextStyle(
            color: baseColor, fontWeight: FontWeight.w500, letterSpacing: 0.5),
      ),
    );
  }

  // ── Dark Theme ──────────────────────────────────────────────────────────────

  static ThemeData darkTheme([Color? seedColor]) {
    final primaryColor = seedColor ?? _primary;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
      surface: _surfaceDark,
      onSurface: _onSurface,
      outline: _borderDark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _bgDark,
      textTheme: _buildTextTheme(_onSurface),
      primaryTextTheme: _buildTextTheme(_onPrimary),

      appBarTheme: AppBarTheme(
        backgroundColor: _bgDark,
        foregroundColor: _onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: _onSurface,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: _onSurfaceVariant),
        actionsIconTheme: const IconThemeData(color: _onSurfaceVariant),
      ),

      cardTheme: CardThemeData(
        color: _surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _borderDark, width: 1),
        ),
        margin: const EdgeInsets.only(bottom: 12),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _surfaceDark,
        indicatorColor: primaryColor.withValues(alpha: 0.2),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: primaryColor, size: 24);
          }
          return const IconThemeData(color: _onSurfaceVariant, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final base = GoogleFonts.inter(fontSize: 12);
          if (states.contains(WidgetState.selected)) {
            return base.copyWith(
                color: primaryColor, fontWeight: FontWeight.w600);
          }
          return base.copyWith(
              color: _onSurfaceVariant, fontWeight: FontWeight.w500);
        }),
        elevation: 0,
        height: 68,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: _onPrimary,
        elevation: 4,
        shape: const StadiumBorder(),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _bgDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        labelStyle: const TextStyle(color: _onSurfaceVariant),
        hintStyle: TextStyle(color: _onSurfaceVariant.withAlpha(150)),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryColor;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(_onPrimary),
        side: const BorderSide(color: _borderDark, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: primaryColor,
        thumbColor: primaryColor,
        overlayColor: primaryColor.withValues(alpha: 0.2),
        inactiveTrackColor: _borderDark,
        valueIndicatorColor: primaryColor,
        valueIndicatorTextStyle: const TextStyle(color: _onPrimary),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: _surfaceDark,
        contentTextStyle: GoogleFonts.inter(color: _onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: _surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: _borderDark),
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: _onSurface,
        ),
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return primaryColor.withValues(alpha: 0.2);
            }
            return _bgDark;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return primaryColor;
            return _onSurfaceVariant;
          }),
          side: WidgetStateProperty.all(
              const BorderSide(color: _borderDark)),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: _borderDark,
        thickness: 1,
        space: 1,
      ),

      listTileTheme: const ListTileThemeData(
        iconColor: _onSurfaceVariant,
        textColor: _onSurface,
        tileColor: Colors.transparent,
      ),
    );
  }

  // ── Light Theme ─────────────────────────────────────────────────────────────

  static ThemeData lightTheme([Color? seedColor]) {
    final primaryColor = seedColor ?? _primaryLight;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      surface: _surfaceLight,
      onSurface: _textLight,
      outline: _borderLight,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _bgLight,
      textTheme: _buildTextTheme(_textLight),
      primaryTextTheme: _buildTextTheme(Colors.white),

      appBarTheme: AppBarTheme(
        backgroundColor: _bgLight,
        foregroundColor: _textLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: _textLight,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: _subTextLight),
        actionsIconTheme: const IconThemeData(color: _subTextLight),
      ),

      cardTheme: CardThemeData(
        color: _surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _borderLight, width: 1),
        ),
        margin: const EdgeInsets.only(bottom: 12),
        shadowColor: const Color(0x0C0F172A),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _surfaceLight,
        indicatorColor: primaryColor.withValues(alpha: 0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: primaryColor, size: 24);
          }
          return const IconThemeData(color: _subTextLight, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final base = GoogleFonts.inter(fontSize: 12);
          if (states.contains(WidgetState.selected)) {
            return base.copyWith(
                color: primaryColor, fontWeight: FontWeight.w600);
          }
          return base.copyWith(
              color: _subTextLight, fontWeight: FontWeight.w500);
        }),
        elevation: 0,
        height: 68,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const StadiumBorder(),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFEDE9FE),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        labelStyle: const TextStyle(color: _subTextLight),
        hintStyle: TextStyle(color: _subTextLight.withAlpha(150)),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryColor;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: _borderLight, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: primaryColor,
        thumbColor: primaryColor,
        overlayColor: primaryColor.withValues(alpha: 0.2),
        inactiveTrackColor: _borderLight,
        valueIndicatorColor: primaryColor,
        valueIndicatorTextStyle: const TextStyle(color: Colors.white),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: _textLight,
        contentTextStyle: GoogleFonts.inter(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: _surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: _borderLight),
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: _textLight,
        ),
        elevation: 8,
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return primaryColor.withValues(alpha: 0.2);
            }
            return _surfaceLight;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return primaryColor;
            return _subTextLight;
          }),
          side: WidgetStateProperty.all(
              const BorderSide(color: _borderLight)),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: _borderLight,
        thickness: 1,
        space: 1,
      ),

      listTileTheme: const ListTileThemeData(
        iconColor: _subTextLight,
        textColor: _textLight,
        tileColor: Colors.transparent,
      ),
    );
  }

  // ── Category Colour Helpers ─────────────────────────────────────────────────

  static const Map<String, Color> categoryColors = {
    'work': Color(0xFF6C5CE7),
    'health': Color(0xFF00D2D3),
    'study': Color(0xFFFD79A8),
    'personal': Color(0xFFFFAA00),
  };

  /// Returns the accent colour for a task category.
  static Color categoryColor(String category) {
    return categoryColors[category.toLowerCase()] ?? _secondary;
  }

  /// Returns the low-opacity background tint for a category pill.
  static Color categoryBg(String category) {
    return categoryColor(category).withAlpha(35);
  }

  // ── Gradient helpers ────────────────────────────────────────────────────────

  /// Primary accent gradient (Indigo → Cyan).
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [_primary, _secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Warm amber gradient for reminders/warnings.
  static const LinearGradient warningGradient = LinearGradient(
    colors: [_warning, _tertiary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
