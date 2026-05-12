import 'package:flutter/material.dart';

/// Editorial v2 palette — pulls from the app-wide light theme so this
/// flow looks like a part of the same product, not a one-off island.
/// If `AppTheme.lightTheme` colors change, mirror them here.
class EditorialPalette {
  static const background = Colors.white;
  static const textPrimary = Colors.black;
  static const textSecondary = Color(0xFF6B7280); // grey-500
  static const textMuted = Color(0xFF9CA3AF);     // grey-400
  static const fieldFill = Color(0xFFF5F5F5);
  static const fieldBorder = Color(0xFFE5E7EB);   // grey-200
  static const fieldBorderFocused = Color(0xFF1A1A1A);
  static const divider = Color(0xFFE5E7EB);
  static const buttonBg = Color(0xFF1A1A1A);
  static const buttonText = Colors.white;
  static const buttonDisabled = Color(0xFFD1D5DB); // grey-300

  // Single accent for "verified / approved" affordances. Pulled from
  // the existing QentColors brand green so the editorial flow doesn't
  // introduce a new colour into the system.
  static const successAccent = Color(0xFF22C55E);
  static const successFill = Color(0xFFE8F8EE); // tint for done-state chips
}
