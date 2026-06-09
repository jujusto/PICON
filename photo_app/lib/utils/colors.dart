import 'package:flutter/material.dart';

class AppColors {
  // --- Palette Picon (bleu marine assombri) ---
  static const Color primary = Color(0xFF01163E);
  static const Color primaryDark = Color(0xFF000A23);
  static const Color primaryLight = Color(0xFF0C2860);
  static const Color accent = Color(0xFF123D78);
  static const Color background = Color(0xFFF5F6F8);
  static const Color card = Colors.white;
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color error = Color(0xFFD32F2F);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textOnPrimary = Colors.white;

  static const Color orangeLight = Color(0xFFFFCC80);
  static const Color greenAir = Color(0xFFE8F5E9);

  /// Nuancier Material dérivé du bleu primaire (thème global).
  static MaterialColor get primarySwatch => MaterialColor(
        primary.value,
        const <int, Color>{
          50: Color(0xFFE8ECF3),
          100: Color(0xFFC5D0E3),
          200: Color(0xFF9EAFCE),
          300: Color(0xFF778EB8),
          400: Color(0xFF5A75A8),
          500: primary,
          600: Color(0xFF011235),
          700: primaryDark,
          800: Color(0xFF000817),
          900: Color(0xFF00040D),
        },
      );
}
