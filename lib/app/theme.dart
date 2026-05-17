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
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0x33221232),
      labelStyle: const TextStyle(color: Color(0xFFB59BC9)),
      hintStyle: const TextStyle(color: Color(0xFF8A7A9B)),
      floatingLabelStyle: const TextStyle(color: Color(0xFFFF6AA7)),
      prefixIconColor: const Color(0xFFFF6AA7),
      suffixIconColor: const Color(0xFFB59BC9),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0x44FF63A4)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0x44FF63A4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF6AA7), width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF3B5C)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF3B5C), width: 1.4),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFF1B1126),
      surfaceTintColor: Color(0xFF1B1126),
      modalBackgroundColor: Color(0xFF1B1126),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFF1B1126),
      surfaceTintColor: const Color(0xFF1B1126),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      titleTextStyle: const TextStyle(
        color: Color(0xFFFFE7F2),
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: const TextStyle(
        color: Color(0xFFD9C5E9),
        fontSize: 14,
        height: 1.4,
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: Color(0xFFFF6AA7),
      textColor: Color(0xFFFFE7F2),
      subtitleTextStyle: TextStyle(color: Color(0xFFB59BC9), fontSize: 12),
    ),
  );
}
