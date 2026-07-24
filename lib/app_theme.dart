import 'package:flutter/material.dart';

// Global theme notifier — updated by any widget, consumed by MyApp
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

/// Semantic colors resolved from the current theme brightness.
class AppColors {
  final Color bg;
  final Color surface;
  final Color card;
  final Color border;
  final Color primary;
  final Color accent;
  final Color textPrimary;
  final Color textMuted;
  final bool isDark;

  const AppColors._({
    required this.bg,
    required this.surface,
    required this.card,
    required this.border,
    required this.primary,
    required this.accent,
    required this.textPrimary,
    required this.textMuted,
    required this.isDark,
  });

  factory AppColors.of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AppColors._(
      bg: dark ? const Color(0xFF000000) : const Color(0xFFF4F6FA),
      surface: dark ? const Color(0xFF0D0D0D) : Colors.white,
      card: dark ? const Color(0xFF111111) : Colors.white,
      border: dark ? const Color(0xFF1E1E2E) : const Color(0xFFE2E8F0),
      primary: const Color(0xFF4338CA),
      accent: const Color(0xFF22C55E),
      textPrimary: dark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
      textMuted: dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
      isDark: dark,
    );
  }
}

class AppTheme {
  // AMOLED-optimised dark theme
  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF000000),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF4338CA),
          secondary: Color(0xFF22C55E),
          surface: Color(0xFF0D0D0D),
          onSurface: Color(0xFFF8FAFC),
          onPrimary: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D0D0D),
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF94A3B8)),
          titleTextStyle: TextStyle(
            color: Color(0xFFF8FAFC),
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        drawerTheme: const DrawerThemeData(backgroundColor: Color(0xFF0D0D0D)),
        cardTheme: CardThemeData(
          color: const Color(0xFF111111),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        dividerColor: const Color(0xFF1E1E2E),
        iconTheme: const IconThemeData(color: Color(0xFF94A3B8)),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Color(0xFFF8FAFC)),
        ),
        progressIndicatorTheme:
            const ProgressIndicatorThemeData(color: Color(0xFF4338CA)),
      );

  // Clean light theme
  static ThemeData get light => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF4F6FA),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF4338CA),
          secondary: Color(0xFF22C55E),
          surface: Colors.white,
          onSurface: Color(0xFF0F172A),
          onPrimary: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF64748B)),
          titleTextStyle: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        drawerTheme: const DrawerThemeData(backgroundColor: Colors.white),
        cardTheme: CardThemeData(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        dividerColor: const Color(0xFFE2E8F0),
        iconTheme: const IconThemeData(color: Color(0xFF64748B)),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Color(0xFF0F172A)),
        ),
        progressIndicatorTheme:
            const ProgressIndicatorThemeData(color: Color(0xFF4338CA)),
      );
}
