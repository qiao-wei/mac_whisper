import 'package:flutter/material.dart';

/// App color definitions for both light and dark themes
class AppColors {
  // Light theme colors
  static const lightBackground = Color(0xFFF5F5F7);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightBorder = Color(0xFFE5E7EB); // grey.shade300 equivalent
  static const lightTextPrimary = Color(0xFF1F2937);
  static const lightTextSecondary = Color(0xFF6B7280);
  static const lightTextMuted = Color(0xFF9CA3AF);
  static const lightHover = Color(0xFFF0F4FF);
  static const lightSelected = Color(0xFFE8F0FE);
  static const lightDivider = Color(0xFFE5E7EB);

  // Dark theme colors (from dard_themes_r reference)
  static const darkBackground = Color(0xFF0F1115); // Main scaffold
  static const darkSurface = Color(0xFF13161F); // Panels, containers
  static const darkSurfaceLight = Color(0xFF1F2430); // Toggle buttons
  static const darkBorder = Color(0xFF4B5563); // grey.shade800 equivalent
  static const darkTextPrimary = Color(0xFFFFFFFF);
  static const darkTextSecondary = Color(0xFF9CA3AF);
  static const darkTextMuted = Color(0xFF6B7280);
  static const darkHover = Color(0xFF0D1420); // Subtitle row hover
  static const darkSelected = Color(0xFF111C30); // Subtitle row selected
  static const darkProjectSelected =
      Color(0xFF1A1E29); // Project list item selected
  static const darkDivider = Color(0xFF4B5563);
  static const darkDropdown = Color(0xFF1E1E2E); // Dropdown menus
  static const darkDialog = Color(0xFF161D2C); // Dialog backgrounds
  static const darkSettingsDialog = Color(0xFF101622); // Settings dialog bg
  static const darkFeatureCard = Color(0xFF0F172A); // Feature card bg
  static const darkFeatureBorder = Color(0xFF1E293B); // Feature card border
  static const darkTogglePanel = Color(0xFF1E2029); // Toggle panel backgrounds
  static const darkInputField = Color(0xFF101622); // Input field backgrounds
  static const darkIconContainer =
      Color(0xFF374151); // grey.shade700 equivalent

  // Shared colors
  static const primary = Color(0xFF2563EB);
  static const primaryLight = Color(0xFF007AFF);
  static const accent = Color(0xFF135BEC);
}

/// Theme-aware color provider
class AppTheme {
  final bool isDark;

  const AppTheme({this.isDark = false});

  // Background colors
  Color get background =>
      isDark ? AppColors.darkBackground : AppColors.lightBackground;
  Color get surface => isDark ? AppColors.darkSurface : AppColors.lightSurface;
  Color get surfaceLight =>
      isDark ? AppColors.darkSurfaceLight : AppColors.lightSurface;

  // Border colors (all borders use the same color for consistency)
  Color get border => isDark ? AppColors.darkBorder : AppColors.lightBorder;
  Color get divider => border; // Use same as border for consistency

  // Text colors
  Color get textPrimary =>
      isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
  Color get textSecondary =>
      isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
  Color get textMuted =>
      isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

  // Interactive colors
  Color get hover => isDark ? AppColors.darkHover : AppColors.lightHover;
  Color get selected =>
      isDark ? AppColors.darkSelected : AppColors.lightSelected;
  Color get projectSelected =>
      isDark ? AppColors.darkProjectSelected : AppColors.lightSelected;
  Color get iconContainer =>
      isDark ? AppColors.darkIconContainer : AppColors.lightBorder;

  // Primary colors (shared)
  Color get primary => AppColors.primary;
  Color get accent => AppColors.accent;

  // Additional UI element colors
  Color get dropdown =>
      isDark ? AppColors.darkDropdown : AppColors.lightSurface;
  Color get dialog => isDark ? AppColors.darkDialog : AppColors.lightSurface;
  Color get settingsDialog =>
      isDark ? AppColors.darkSettingsDialog : AppColors.lightSurface;
  Color get featureCard =>
      isDark ? AppColors.darkFeatureCard : AppColors.lightSurface;
  Color get featureBorder =>
      isDark ? AppColors.darkFeatureBorder : AppColors.lightBorder;
  Color get togglePanel =>
      isDark ? AppColors.darkTogglePanel : AppColors.lightSurface;
  Color get inputField =>
      isDark ? AppColors.darkInputField : AppColors.lightSurface;

  // Video player colors (always dark themed for video)
  Color get videoBackground => Colors.black;
  Color get videoControlsBg =>
      isDark ? Colors.black.withOpacity(0.7) : AppColors.lightSurface;
  Color get videoControlsText =>
      isDark ? Colors.white : AppColors.lightTextPrimary;
  Color get videoProgressBg =>
      isDark ? Colors.grey.shade700 : Colors.grey.shade300;
  Color get videoProgressFill => isDark ? Colors.white : AppColors.primary;

  // Sidebar colors
  Color get sidebarBg =>
      isDark ? const Color(0xFF080A0F) : AppColors.lightSurface;

  // Get Flutter ThemeData
  ThemeData get themeData {
    if (isDark) {
      return ThemeData.dark().copyWith(
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.dark(
          primary: AppColors.primaryLight,
          surface: surface,
        ),
      );
    } else {
      return ThemeData.light().copyWith(
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.light(
          primary: AppColors.primaryLight,
          surface: surface,
        ),
      );
    }
  }
}
