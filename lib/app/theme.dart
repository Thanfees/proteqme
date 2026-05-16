import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

ThemeData buildAppTheme() {
  const seed = Color(0xFFFF2C7A);
  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
      ).copyWith(
        surface: const Color(0xFF1B1126),
        secondary: const Color(0xFFFF6FA8),
        tertiary: const Color(0xFF4BEA89),
        error: const Color(0xFFFF6B6B),
      );

  return ThemeData(
    colorScheme: colorScheme,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF08030F),
    useMaterial3: true,
    textTheme: GoogleFonts.lexendTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Color(0xFFFFE9F2),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: const Color(0xFF1B1126),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Color(0xFF241733),
      contentTextStyle: TextStyle(color: Color(0xFFFFE8F3)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFE91E63),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFFFD6E8),
        side: const BorderSide(color: Color(0xAAFF4F93)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}
