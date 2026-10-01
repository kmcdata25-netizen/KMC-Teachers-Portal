import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens and Material 3 theme configuration for Kasarani Music Center Teacher Portal.
/// Matches the student client app's brand identity and design benchmarks.
class AppTheme {
  AppTheme._();

  // KMC brand palette
  static const Color primaryBackground = Color(0xFF061C2D);
  static const Color surfaceCard = Color(0xFF0B2B43);
  static const Color surfaceElevated = Color(0xFF123B57);
  static const Color surfaceElevatedHigh = Color(0xFF1A4869);
  static const Color brandBlue = Color(0xFF075780);
  static const Color brandGreen = Color(0xFF35C400);
  static const Color brandGreenDark = Color(0xFF258F0A);
  static const Color accentSky = Color(0xFF69C5E6);
  static const Color brandGold = Color(0xFFF0BD55);
  static const Color danger = Color(0xFFE57668);
  static const Color accentCoral = Color(0xFFE57668);
  static const Color textWhite = Color(0xFFF5F9FB);
  static const Color textMuted = Color(0xFFB8CBD7);
  static const Color borderOutline = Color(0xFF28516B);

  // Backwards-compatible aliases
  static const Color neonGreen = brandGreen;
  static const Color neonGreenDim = Color(0x3335C400);

  // Card Border Radius Token
  static final BorderRadius cardBorderRadius = BorderRadius.circular(12);

  /// Primary Material 3 Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: primaryBackground,
      primaryColor: brandGreen,
      splashFactory: InkSparkle.splashFactory,
      materialTapTargetSize: MaterialTapTargetSize.padded,

      // Color Scheme
      colorScheme: const ColorScheme.dark(
        primary: brandGreen,
        onPrimary: Color(0xFF061C2D),
        primaryContainer: Color(0xFF174B1C),
        onPrimaryContainer: Color(0xFFD9FFD0),
        secondary: accentSky,
        onSecondary: Color(0xFF061C2D),
        secondaryContainer: Color(0xFF123B57),
        onSecondaryContainer: textWhite,
        tertiary: brandGold,
        onTertiary: Color(0xFF302100),
        surface: surfaceCard,
        onSurface: textWhite,
        surfaceContainerLowest: primaryBackground,
        surfaceContainerLow: primaryBackground,
        surfaceContainer: surfaceCard,
        surfaceContainerHigh: surfaceElevated,
        surfaceContainerHighest: Color(0xFF283248),
        outline: borderOutline,
        outlineVariant: Color(0xFF1A4059),
        error: danger,
        onError: primaryBackground,
      ),

      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryBackground,
        foregroundColor: textWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textWhite,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        iconTheme: IconThemeData(color: textWhite),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: cardBorderRadius,
          side: const BorderSide(color: borderOutline, width: 1),
        ),
      ),

      // Navigation Bar (Material 3 with pill-shaped indicator)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceCard,
        elevation: 0,
        indicatorColor: brandGreen.withValues(alpha: 0.18),
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: brandGreen, size: 24);
          }
          return const IconThemeData(color: textMuted, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: brandGreen,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            );
          }
          return const TextStyle(
            color: textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          );
        }),
      ),

      // Tab Bar Theme
      tabBarTheme: const TabBarThemeData(
        labelColor: brandGreen,
        unselectedLabelColor: textMuted,
        indicatorColor: brandGreen,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: borderOutline,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
      ),

      // SnackBar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceElevated,
        contentTextStyle: const TextStyle(
          color: textWhite,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: brandGreen,
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: borderOutline, width: 1),
        ),
      ),

      // Filled Button Theme
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brandGreen,
          foregroundColor: primaryBackground,
          elevation: 0,
          minimumSize: const Size(64, 46),
          tapTargetSize: MaterialTapTargetSize.padded,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            color: primaryBackground,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textWhite,
          minimumSize: const Size(64, 46),
          tapTargetSize: MaterialTapTargetSize.padded,
          side: const BorderSide(color: borderOutline, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),

      // Progress Indicator Theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: brandGreen,
        linearTrackColor: surfaceElevated,
        circularTrackColor: surfaceElevated,
      ),

      // Typography
      textTheme: GoogleFonts.nunitoSansTextTheme(
        const TextTheme(
          headlineLarge: TextStyle(
            color: textWhite,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
          headlineMedium: TextStyle(
            color: textWhite,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          titleLarge: TextStyle(
            color: textWhite,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
          titleMedium: TextStyle(
            color: textWhite,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: TextStyle(
            color: textWhite,
            fontSize: 14,
          ),
          bodyMedium: TextStyle(
            color: textMuted,
            fontSize: 13,
          ),
          labelSmall: TextStyle(
            color: textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: borderOutline,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
