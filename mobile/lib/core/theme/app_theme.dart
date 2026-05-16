import 'package:flutter/material.dart';

class AppTheme {
  // 1. Core Brand Color (Stays the same in both themes)
  static const Color primaryColor = Color(0xFF7C3AED); // The vibrant purple

  // Playlist-specific tokens (centralized here so pages use theme colors)
  static const Color playlistPageBg = Color(0xFF0E0A1A);
  static const Color playlistHeroTop = Color(0xFF1E1040);
  static const Color playlistHeroMid = Color(0xFF120D2E);
  static const Color playlistCardBg = Color(0x0AFFFFFF);
  static const Color playlistCardBgHover = Color(0x12FFFFFF);
  static const Color playlistCardBgActive = Color(0x1F7C3AED);

  static const Color playlistBorderSubtle = Color(0x0FFFFFFF);
  static const Color playlistBorderCard = Color(0x1F7C3AED);
  static const Color playlistBorderPurple = Color(0x597C3AED);

  static const Color playlistPurple = primaryColor;
  static const Color playlistPurpleLight = Color(0xFF9B65FF);

  static const Color playlistTextPrimary = Color(0xDEFFFFFF);
  static const Color playlistTextSecondary = Color(0x72FFFFFF);
  static const Color playlistTextMuted = Color(0x3DFFFFFF);

  static const List<List<Color>> playlistArtworkGradients = [
    [Color(0xFF4A1D9E), Color(0xFF7C3AED)],
    [Color(0xFF1E1040), Color(0xFF3A1280)],
    [Color(0xFF2A1660), Color(0xFF5A2AA8)],
    [Color(0xFF7C3AED), Color(0xFF9B55FF)],
  ];

  static const List<List<Color>> playlistThumbGradients = [
    [Color(0xFF4A1D9E), Color(0xFF7C3AED)],
    [Color(0xFF0F6E56), Color(0xFF1D9E75)],
    [Color(0xFF993C1D), Color(0xFFD85A30)],
    [Color(0xFF185FA5), Color(0xFF378ADD)],
    [Color(0xFF639922), Color(0xFF97C459)],
  ];

  // --- Light Theme Colors ---
  static const Color _lightBackground = Colors.white;
  static const Color _lightSurface = Color(
    0xFFF3E8FF,
  ); // Light purple for chips
  static const Color _lightTextTitle = Color(0xFF111827); // Dark gray/black
  static const Color _lightTextSubtitle = Color(0xFF6B7280); // Medium gray

  // --- Dark Theme Colors ---
  static const Color _darkBackground = Color(0xFF121212); // Deep dark gray
  static const Color _darkSurface = Color(
    0xFF2D2D3A,
  ); // Darker surface for chips
  static const Color _darkTextTitle = Colors.white; // White text for contrast
  static const Color _darkTextSubtitle = Color(
    0xFF9CA3AF,
  ); // Light gray for reading

  // ==========================================
  // 2. LIGHT THEME CONFIGURATION
  // ==========================================
  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: _lightBackground,

      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: _lightSurface,
        primaryContainer: primaryColor.withValues(alpha: 0.15),
        onPrimaryContainer: primaryColor,
      ),

      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: _lightTextTitle,
          height: 1.2,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: _lightTextSubtitle,
          height: 1.5,
        ),
        labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: _lightBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: _lightTextTitle),
        titleTextStyle: TextStyle(
          color: _lightTextTitle,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
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

      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        onPrimary: Colors.white,
        secondary: _darkSurface,
        primaryContainer: primaryColor.withValues(alpha: 0.3),
        onPrimaryContainer: const Color(0xFFD8B4FE),
      ),

      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: _darkTextTitle,
          height: 1.2,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: _darkTextSubtitle,
          height: 1.5,
        ),
        labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor:
              Colors.white, // The text inside the button stays white
          elevation: 0,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: _darkBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: _darkTextTitle),
        titleTextStyle: TextStyle(
          color: _darkTextTitle,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
