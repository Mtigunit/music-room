import 'package:flutter/material.dart';

class AppTheme {
  // 1. Core Brand Color (Stays the same in both themes)
  static const Color primaryColor = Color(0xFF7C3AED); // The vibrant purple

  // --- Light Theme Colors ---
  static const Color _lightBackground = Colors.white;
  static const Color _lightSurface = Color(0xFFF3E8FF); // Light purple for chips
  static const Color _lightTextTitle = Color(0xFF111827); // Dark gray/black
  static const Color _lightTextSubtitle = Color(0xFF6B7280); // Medium gray

  // --- Dark Theme Colors ---
  static const Color _darkBackground = Color(0xFF121212); // Deep dark gray
  static const Color _darkSurface = Color(0xFF2D2D3A); // Darker surface for chips
  static const Color _darkTextTitle = Colors.white; // White text for contrast
  static const Color _darkTextSubtitle = Color(0xFF9CA3AF); // Light gray for reading

  // ==========================================
  // 2. LIGHT THEME CONFIGURATION
  // ==========================================
  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: _lightBackground,
      
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: _lightSurface,
        surface: _lightBackground,
      ),

      textTheme: const TextTheme(
        displaySmall: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: _lightTextTitle, height: 1.2),
        bodyLarge: TextStyle(fontSize: 16, color: _lightTextSubtitle, height: 1.5),
        labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: _lightBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: _lightTextTitle),
        titleTextStyle: TextStyle(color: _lightTextTitle, fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ==========================================
  // 3. DARK THEME CONFIGURATION
  // ==========================================
  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: _darkBackground,
      
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: _darkSurface,
        surface: _darkBackground,
      ),

      textTheme: const TextTheme(
        displaySmall: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: _darkTextTitle, height: 1.2),
        bodyLarge: TextStyle(fontSize: 16, color: _darkTextSubtitle, height: 1.5),
        labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white, // The text inside the button stays white
          elevation: 0,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: _darkBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: _darkTextTitle),
        titleTextStyle: TextStyle(color: _darkTextTitle, fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }
}