// lib/config/app_theme.dart
import 'package:flutter/material.dart';
import '../components/app_colors.dart';

class AppTheme {
  // Pacifico text styles for titles and labels
  static const TextStyle pacificoDisplayLarge = TextStyle(fontFamily: 'Pacifico');
  static const TextStyle pacificoDisplayMedium = TextStyle(fontFamily: 'Pacifico');
  static const TextStyle pacificoDisplaySmall = TextStyle(fontFamily: 'Pacifico');

  static const TextStyle pacificoHeadlineLarge = TextStyle(fontFamily: 'Pacifico');
  static const TextStyle pacificoHeadlineMedium = TextStyle(fontFamily: 'Pacifico');
  static const TextStyle pacificoHeadlineSmall = TextStyle(fontFamily: 'Pacifico');

  static const TextStyle pacificoTitleLarge = TextStyle(fontFamily: 'Pacifico');
  static const TextStyle pacificoTitleMedium = TextStyle(fontFamily: 'Pacifico');
  static const TextStyle pacificoTitleSmall = TextStyle(fontFamily: 'Pacifico');

  static const TextStyle pacificoLabelLarge = TextStyle(fontFamily: 'Pacifico');
  static const TextStyle pacificoLabelMedium = TextStyle(fontFamily: 'Pacifico');
  static const TextStyle pacificoLabelSmall = TextStyle(fontFamily: 'Pacifico');

  // Main theme data
  static ThemeData get lightTheme {
    return ThemeData(
      primarySwatch: Colors.green,
      // FIX: This was causing the '₱' symbol issue. Removing it makes the app use the default system font.
      useMaterial3: true,
      typography: Typography.material2021(),

      // Universal AppBar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 4.0, // Add elevation on scroll
        surfaceTintColor: Colors.transparent, // Prevent color change on scroll
        foregroundColor: AppColors.primaryColor,
        titleTextStyle: TextStyle(
          fontFamily: 'Pacifico',
          color: AppColors.primaryColor,
          fontSize: 24,
        ),
        iconTheme: IconThemeData(
          color: AppColors.primaryColor,
        ),
      ),

      // Text theme with Pacifico for titles/labels, and default system font for body text.
      textTheme: const TextTheme(
        // Display styles - Pacifico
        displayLarge: pacificoDisplayLarge,
        displayMedium: pacificoDisplayMedium,
        displaySmall: pacificoDisplaySmall,

        // Headline styles - Pacifico
        headlineLarge: pacificoHeadlineLarge,
        headlineMedium: pacificoHeadlineMedium,
        headlineSmall: pacificoHeadlineSmall,

        // Title styles - Pacifico
        titleLarge: pacificoTitleLarge,
        titleMedium: pacificoTitleMedium,
        titleSmall: pacificoTitleSmall,

        // Body styles - FIX: Removed explicit 'Lato' font to use the default system font.
        bodyLarge: TextStyle(color: AppColors.primaryColor),
        bodyMedium: TextStyle(color: AppColors.primaryColor),
        bodySmall: TextStyle(color: AppColors.primaryColor),

        // Label styles - Pacifico
        labelLarge: pacificoLabelLarge,
        labelMedium: pacificoLabelMedium,
        labelSmall: pacificoLabelSmall,
      ),
    );
  }

  // Convenience methods to apply Pacifico styles with custom properties
  static TextStyle pacifico({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: 'Pacifico',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  // Convenience methods to apply Lato styles with custom properties
  static TextStyle lato({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
  }) {
    return TextStyle(
      // FIX: Removed to ensure default system font is used.
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      fontStyle: fontStyle,
    );
  }
}
