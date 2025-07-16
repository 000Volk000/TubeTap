import 'package:flutter/material.dart';

/// Paleta de colores Coral Red para TubeTap
class AppColors {
  // Coral Red Palette
  static const Color coralRed50 = Color(0xFFFFF1F1);
  static const Color coralRed100 = Color(0xFFFFDFE0);
  static const Color coralRed200 = Color(0xFFFFC5C6);
  static const Color coralRed300 = Color(0xFFFF9D9F);
  static const Color coralRed400 = Color(0xFFFF6467);
  static const Color coralRed500 = Color(0xFFFF3B3F); // Color principal
  static const Color coralRed600 = Color(0xFFED1519);
  static const Color coralRed700 = Color(0xFFC80D11);
  static const Color coralRed800 = Color(0xFFA50F12);
  static const Color coralRed900 = Color(0xFF881416);
  static const Color coralRed950 = Color(0xFF4B0405);

  // Colores principales de la app
  static const Color primary = coralRed500;
  static const Color primaryDark = coralRed600;
  static const Color accent = coralRed400;
  static const Color background = coralRed50;
  static const Color surface = Colors.white;
  static const Color error = coralRed700;

  // Colores de texto
  static const Color textPrimary = coralRed950;
  static const Color textSecondary = coralRed800;
  static const Color textOnPrimary = Colors.white;

  // Método para crear MaterialColor desde coral red
  static MaterialColor get coralRedMaterialColor {
    return MaterialColor(coralRed500.value, const <int, Color>{
      50: coralRed50,
      100: coralRed100,
      200: coralRed200,
      300: coralRed300,
      400: coralRed400,
      500: coralRed500,
      600: coralRed600,
      700: coralRed700,
      800: coralRed800,
      900: coralRed900,
    });
  }
}
