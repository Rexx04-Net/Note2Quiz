import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.primarySoft,
    required this.primaryText,
    required this.mutedText,
    required this.subtleText,
    required this.overlay,
  });

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color primarySoft;
  final Color primaryText;
  final Color mutedText;
  final Color subtleText;
  final Color overlay;

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? primarySoft,
    Color? primaryText,
    Color? mutedText,
    Color? subtleText,
    Color? overlay,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      primarySoft: primarySoft ?? this.primarySoft,
      primaryText: primaryText ?? this.primaryText,
      mutedText: mutedText ?? this.mutedText,
      subtleText: subtleText ?? this.subtleText,
      overlay: overlay ?? this.overlay,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t) ?? background,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t) ?? surfaceAlt,
      border: Color.lerp(border, other.border, t) ?? border,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t) ?? primarySoft,
      primaryText: Color.lerp(primaryText, other.primaryText, t) ?? primaryText,
      mutedText: Color.lerp(mutedText, other.mutedText, t) ?? mutedText,
      subtleText: Color.lerp(subtleText, other.subtleText, t) ?? subtleText,
      overlay: Color.lerp(overlay, other.overlay, t) ?? overlay,
    );
  }
}

class StudyAppTheme {
  static const AppColors _darkColors = AppColors(
    background: Color(0xFF12121A),
    surface: Color(0xFF1A1A26),
    surfaceAlt: Color(0xFF232334),
    border: Color(0x1FFFFFFF),
    primarySoft: Color(0x226C63FF),
    primaryText: Color(0xFFB8B3FF),
    mutedText: Color(0xB3FFFFFF),
    subtleText: Color(0x80FFFFFF),
    overlay: Color(0xF2181823),
  );

  static const AppColors _lightColors = AppColors(
    background: Color(0xFFF5F7FB),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF1F4FB),
    border: Color(0x1A1A2440),
    primarySoft: Color(0x1F3451FF),
    primaryText: Color(0xFF3451FF),
    mutedText: Color(0xCC1F2430),
    subtleText: Color(0x801F2430),
    overlay: Color(0xEAF5F7FB),
  );

  static ThemeData lightTheme() {
    const primary = Color(0xFF3451FF);
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: primary,
      secondary: const Color(0xFFFF8C42),
      surface: _lightColors.surface,
    );

    return _buildTheme(
      colorScheme: scheme,
      appColors: _lightColors,
      brightness: Brightness.light,
    );
  }

  static ThemeData darkTheme() {
    const primary = Color(0xFF6C63FF);
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: primary,
      secondary: Colors.orangeAccent,
      surface: _darkColors.surface,
    );

    return _buildTheme(
      colorScheme: scheme,
      appColors: _darkColors,
      brightness: Brightness.dark,
    );
  }

  static ThemeData _buildTheme({
    required ColorScheme colorScheme,
    required AppColors appColors,
    required Brightness brightness,
  }) {
    final textTheme = GoogleFonts.dmSansTextTheme().apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: appColors.background,
      textTheme: textTheme,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: appColors.surfaceAlt,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: appColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: appColors.surfaceAlt,
        hintStyle: textTheme.bodyMedium?.copyWith(color: appColors.subtleText),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: appColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary),
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[appColors],
    );
  }
}

extension AppThemeContext on BuildContext {
  ThemeData get appTheme => Theme.of(this);
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}
