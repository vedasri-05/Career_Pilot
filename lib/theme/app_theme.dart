import 'package:flutter/material.dart';

class AppTheme {
  // Brand color palette: deep navy, royal blue, violet, teal, and clean neutrals
  static const Color primaryBlue = Color(0xFF1A56DB); // Vibrant royal blue
  static const Color darkBlue = Color(0xFF0F274E); // Deep navy blue
  static const Color lightBlue = Color(0xFF0284C7); // Sky/ocean blue
  static const Color violet = Color(0xFF7C3AED); // Modern violet
  static const Color teal = Color(0xFF0D9488); // Crisp emerald teal
  static const Color amber = Color(0xFFD97706); // Warm amber
  static const Color rose = Color(0xFFE11D48); // Energetic rose/coral
  static const Color textDark = Color(0xFF0F172A); // Slate 900
  static const Color textMedium = Color(0xFF475569); // Slate 600
  static const Color textMuted = Color(0xFF94A3B8); // Slate 400
  static const Color background = Color(0xFFF8FAFC);
  static const Color cardColor = Colors.white;

  // Semantic aliases
  static const Color scaffoldBackground = background;
  static const Color surfaceLight = Color(0xFFF1F5F9);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color darkNavy = darkBlue;
  static const Color textSecondary = textMedium;
  static const Color accentTeal = teal;
  static const Color accentAmber = amber;
  static const Color accentRose = rose;
  static const Color accentViolet = violet;

  // Rich, modern colourful background gradient
  static const LinearGradient colorfulBackgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFEEF2FF), // Soft Royal/Indigo 50
      Color(0xFFF5F3FF), // Soft Violet 50
      Color(0xFFF0FDF4), // Soft Emerald 50
      Color(0xFFFFFBEB), // Soft Amber 50
      Color(0xFFF8FAFC), // Slate 50
    ],
    stops: [0.0, 0.28, 0.58, 0.85, 1.0],
  );

  // Gradients for headers, hero banners, and key visual cards
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0F274E), Color(0xFF1A56DB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient violetGradient = LinearGradient(
    colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient tealGradient = LinearGradient(
    colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient amberGradient = LinearGradient(
    colors: [Color(0xFFB45309), Color(0xFFF59E0B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [
      Color(0xFF0A1931), // Deep navy
      Color(0xFF1A3670), // Royal indigo
      Color(0xFF312E81), // Violet indigo
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Soft modern shadow for cards
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.06),
      blurRadius: 18,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.02),
      blurRadius: 6,
      offset: const Offset(0, 1),
    ),
  ];

  // Elevated shadow for primary interactive cards
  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: primaryBlue.withValues(alpha: 0.22),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ];

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryBlue,
      primary: primaryBlue,
      secondary: violet,
      tertiary: teal,
      surface: cardColor,
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: textDark,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.bold,
        color: textDark,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      hintStyle: const TextStyle(color: textMuted, fontSize: 14),
      labelStyle: const TextStyle(
        color: textMedium,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primaryBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: rose, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: rose, width: 2),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 1,
        shadowColor: primaryBlue.withValues(alpha: 0.3),
        minimumSize: const Size(double.infinity, 52),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryBlue,
        side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
        minimumSize: const Size(double.infinity, 50),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      elevation: 4,
      shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.1),
      indicatorColor: primaryBlue.withValues(alpha: 0.14),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: primaryBlue,
          );
        }
        return const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textMedium,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: primaryBlue, size: 24);
        }
        return const IconThemeData(color: textMedium, size: 24);
      }),
    ),
  );
}
