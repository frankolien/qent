import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Qent brand colors — matches the web dark UI
class QentColors {
  // Primary
  static const accent = Color(0xFF22C55E);       // Green accent
  static const accentDark = Color(0xFF16A34A);    // Darker green for pressed states

  // Dark theme surfaces
  static const background = Color(0xFF0A0A0A);    // Main background
  static const surface = Color(0xFF111111);        // Cards, elevated surfaces
  static const surfaceLight = Color(0xFF1A1A1A);   // Slightly lighter surface
  static const surfaceBorder = Color(0xFF1F1F1F);  // Borders between surfaces

  // Text
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFF9CA3AF);  // grey-400
  static const textTertiary = Color(0xFF6B7280);   // grey-500
  static const textMuted = Color(0xFF4B5563);      // grey-600

  // Semantic
  static const error = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const info = Color(0xFF3B82F6);
  static const success = Color(0xFF22C55E);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: QentColors.background,
      primaryColor: QentColors.accent,
      colorScheme: const ColorScheme.dark(
        primary: QentColors.accent,
        secondary: QentColors.accent,
        surface: QentColors.surface,
        error: QentColors.error,
      ),
      textTheme: GoogleFonts.robotoTextTheme(
        ThemeData.dark().textTheme,
      ).apply(
        bodyColor: QentColors.textPrimary,
        displayColor: QentColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: QentColors.background,
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        color: QentColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: QentColors.background,
        selectedItemColor: QentColors.accent,
        unselectedItemColor: QentColors.textTertiary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: QentColors.surface,
        hintStyle: const TextStyle(color: QentColors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: QentColors.accent.withValues(alpha: 0.4)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: QentColors.accent,
          foregroundColor: QentColors.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.06),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: QentColors.surfaceLight,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      primaryColor: QentColors.accent,
      colorScheme: const ColorScheme.light(
        primary: QentColors.accent,
        secondary: QentColors.accent,
        surface: Colors.white,
        error: QentColors.error,
      ),
      textTheme: GoogleFonts.robotoTextTheme(
        ThemeData.light().textTheme,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: QentColors.accent,
        unselectedItemColor: Color(0xFF9CA3AF),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: QentColors.accent.withValues(alpha: 0.6)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A1A1A),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1A1A1A),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Theme-aware color helpers — use `context.bgPrimary`, `context.textPrimary`, etc.
extension QentTheme on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  // Backgrounds
  Color get bgPrimary => isDark ? const Color(0xFF0A0A0A) : Colors.white;
  Color get bgSecondary => isDark ? const Color(0xFF151515) : const Color(0xFFF5F5F5);
  Color get bgTertiary => isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF0F0F0);
  Color get bgCard => isDark ? const Color(0xFF111111) : Colors.white;

  // Text
  Color get textPrimary => isDark ? Colors.white : Colors.black;
  Color get textSecondary => isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
  Color get textTertiary => isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF);

  // Borders & dividers
  Color get borderColor => isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB);
  Color get dividerColor => isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE5E7EB);

  // Inputs
  Color get inputBg => isDark ? const Color(0xFF151515) : const Color(0xFFF5F5F5);
  Color get inputBorder => isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB);

  // Nav bar
  Color get navBarBg => isDark ? const Color(0xFF111111) : Colors.white;

  // Accent
  Color get accent => const Color(0xFF22C55E);
}
