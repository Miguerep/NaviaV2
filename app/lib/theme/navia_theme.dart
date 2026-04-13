import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NaviaThemeTokens {
  static const primary = Color(0xFF0053CC);
  static const primaryDim = Color(0xFF0048B3);
  static const secondary = Color(0xFF00675C);

  static const surface = Color(0xFFF8F5FF);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFF0EFFF);
  static const surfaceContainer = Color(0xFFE6E6FF);
  static const surfaceContainerHighest = Color(0xFFD8DAFF);

  static const onSurface = Color(0xFF272C51);
  static const onSurfaceVariant = Color(0xFF545981);

  static const outline = Color(0xFF6F749E);
  static const outlineVariant = Color(0xFFA6AAD7);

  static const error = Color(0xFFB31B25);
  static const errorContainer = Color(0xFFFB5151);

  static const pagePadding = EdgeInsets.symmetric(horizontal: 24);
}

class NaviaTheme {
  static ThemeData light({bool highContrast = false}) {
    final scaffold = highContrast
        ? Colors.white
        : NaviaThemeTokens.surface;
    final onSurface = highContrast
        ? Colors.black
        : NaviaThemeTokens.onSurface;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: NaviaThemeTokens.primary,
      brightness: Brightness.light,
      primary: NaviaThemeTokens.primary,
      secondary: NaviaThemeTokens.secondary,
      surface: scaffold,
      error: NaviaThemeTokens.error,
      onSurface: onSurface,
    );

    final base = ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scaffold,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: NaviaThemeTokens.surfaceContainerHighest,
        labelStyle: const TextStyle(
          color: NaviaThemeTokens.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: const TextStyle(
          color: NaviaThemeTokens.onSurface,
          fontWeight: FontWeight.w700,
        ),
        helperStyle: TextStyle(
          color: NaviaThemeTokens.onSurfaceVariant.withValues(alpha: 0.75),
          fontWeight: FontWeight.w500,
        ),
        errorStyle: const TextStyle(
          color: NaviaThemeTokens.error,
          fontWeight: FontWeight.w600,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(20),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: NaviaThemeTokens.outlineVariant,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: NaviaThemeTokens.primary,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: NaviaThemeTokens.error,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: NaviaThemeTokens.error,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        hintStyle: TextStyle(
          color: NaviaThemeTokens.onSurfaceVariant.withValues(alpha: 0.6),
          fontWeight: FontWeight.w500,
        ),
      ),
    );

    final textTheme = GoogleFonts.lexendTextTheme(base.textTheme).copyWith(
      titleLarge: GoogleFonts.lexend(fontWeight: FontWeight.w800),
      titleMedium: GoogleFonts.lexend(fontWeight: FontWeight.w700),
      bodyLarge: GoogleFonts.lexend(fontWeight: FontWeight.w500, fontSize: 16),
      bodyMedium: GoogleFonts.lexend(fontWeight: FontWeight.w500),
      labelLarge: GoogleFonts.lexend(fontWeight: FontWeight.w600),
    );

    return base.copyWith(
      textTheme: textTheme,
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size.fromHeight(56)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          ),
          textStyle: WidgetStatePropertyAll(
            GoogleFonts.lexend(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          backgroundColor: const WidgetStatePropertyAll(NaviaThemeTokens.primary),
          foregroundColor:
              const WidgetStatePropertyAll(NaviaThemeTokens.surfaceContainerLowest),
        ),
      ),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        indicatorColor: NaviaThemeTokens.surfaceContainer,
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.lexend(fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ),
    );
  }
}

