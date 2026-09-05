import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.cardBorder,
    required this.primarySoft,
    required this.primaryText,
    required this.mutedText,
    required this.subtleText,
    required this.overlay,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.error,
    required this.errorSoft,
    required this.info,
    required this.infoSoft,
    required this.accent,
    required this.accentSoft,
  });

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color cardBorder;
  final Color primarySoft;
  final Color primaryText;
  final Color mutedText;
  final Color subtleText;
  final Color overlay;

  // Semantic States
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color error;
  final Color errorSoft;
  final Color info;
  final Color infoSoft;
  final Color accent;
  final Color accentSoft;

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? cardBorder,
    Color? primarySoft,
    Color? primaryText,
    Color? mutedText,
    Color? subtleText,
    Color? overlay,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? error,
    Color? errorSoft,
    Color? info,
    Color? infoSoft,
    Color? accent,
    Color? accentSoft,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      cardBorder: cardBorder ?? this.cardBorder,
      primarySoft: primarySoft ?? this.primarySoft,
      primaryText: primaryText ?? this.primaryText,
      mutedText: mutedText ?? this.mutedText,
      subtleText: subtleText ?? this.subtleText,
      overlay: overlay ?? this.overlay,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      error: error ?? this.error,
      errorSoft: errorSoft ?? this.errorSoft,
      info: info ?? this.info,
      infoSoft: infoSoft ?? this.infoSoft,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
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
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t) ?? cardBorder,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t) ?? primarySoft,
      primaryText: Color.lerp(primaryText, other.primaryText, t) ?? primaryText,
      mutedText: Color.lerp(mutedText, other.mutedText, t) ?? mutedText,
      subtleText: Color.lerp(subtleText, other.subtleText, t) ?? subtleText,
      overlay: Color.lerp(overlay, other.overlay, t) ?? overlay,
      success: Color.lerp(success, other.success, t) ?? success,
      successSoft: Color.lerp(successSoft, other.successSoft, t) ?? successSoft,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t) ?? warningSoft,
      error: Color.lerp(error, other.error, t) ?? error,
      errorSoft: Color.lerp(errorSoft, other.errorSoft, t) ?? errorSoft,
      info: Color.lerp(info, other.info, t) ?? info,
      infoSoft: Color.lerp(infoSoft, other.infoSoft, t) ?? infoSoft,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t) ?? accentSoft,
    );
  }
}

class StudyAppTheme {
  // Electric Azure Blue & Obsidian Black Palette (Dark Mode)
  static const AppColors _darkColors = AppColors(
    background: Color(0xFF080B11),       // Deep obsidian black background
    surface: Color(0xFF101522),          // Deep slate-navy surface
    surfaceAlt: Color(0xFF161E30),       // Secondary elevated surface / inputs
    border: Color(0xFF1E293B),           // Refined dark border
    cardBorder: Color(0xFF25334E),       // Subtle card outline
    primarySoft: Color(0x280062FE),      // Logo blue soft glow tint
    primaryText: Color(0xFFF8FAFC),      // Crisp white text
    mutedText: Color(0xFF94A3B8),        // Slate grey body text
    subtleText: Color(0xFF64748B),       // Refined muted caption
    overlay: Color(0xF2080B11),          // Obsidian overlay
    success: Color(0xFF10B981),          // Emerald success
    successSoft: Color(0x2410B981),
    warning: Color(0xFFF59E0B),          // Amber warning
    warningSoft: Color(0x24F59E0B),
    error: Color(0xFFEF4444),            // Coral error
    errorSoft: Color(0x24EF4444),
    info: Color(0xFF38BDF8),             // Sky blue info
    infoSoft: Color(0x2438BDF8),
    accent: Color(0xFF0062FE),           // Brand Logo Azure Blue
    accentSoft: Color(0x260062FE),
  );

  // Clean Modern Blue & Porcelain Palette (Light Mode)
  static const AppColors _lightColors = AppColors(
    background: Color(0xFFF8FAFC),       // Clean light porcelain canvas
    surface: Color(0xFFFFFFFF),          // Pure ivory white card
    surfaceAlt: Color(0xFFF1F5F9),       // Soft slate cream
    border: Color(0xFFE2E8F0),           // Crisp hairline border
    cardBorder: Color(0xFFCBD5E1),       // Subtle card border
    primarySoft: Color(0x1F0062FE),      // Logo blue soft tint
    primaryText: Color(0xFF0F172A),      // Deep slate charcoal
    mutedText: Color(0xFF475569),        // Slate body text
    subtleText: Color(0xFF94A3B8),       // Muted caption
    overlay: Color(0xF2F8FAFC),
    success: Color(0xFF059669),
    successSoft: Color(0x20059669),
    warning: Color(0xFFD97706),
    warningSoft: Color(0x20D97706),
    error: Color(0xFFDC2626),
    errorSoft: Color(0x20DC2626),
    info: Color(0xFF0284C7),
    infoSoft: Color(0x200284C7),
    accent: Color(0xFF0062FE),           // Brand Logo Azure Blue
    accentSoft: Color(0x200062FE),
  );

  static ThemeData lightTheme() {
    const primary = Color(0xFF0062FE);
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: primary,
      onPrimary: const Color(0xFFFFFFFF),
      secondary: const Color(0xFF0F172A),
      onSecondary: const Color(0xFFFFFFFF),
      surface: _lightColors.surface,
      onSurface: const Color(0xFF0F172A),
    );

    return _buildTheme(
      colorScheme: scheme,
      appColors: _lightColors,
      brightness: Brightness.light,
    );
  }

  static ThemeData darkTheme() {
    const primary = Color(0xFF0062FE);
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: primary,
      onPrimary: const Color(0xFFFFFFFF),
      secondary: const Color(0xFFF8FAFC),
      onSecondary: const Color(0xFF080B11),
      surface: _darkColors.surface,
      onSurface: const Color(0xFFF8FAFC),
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
    // Body and interface: Clean modern Sans (Plus Jakarta Sans)
    final sansTextTheme = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData(brightness: brightness).textTheme,
    );

    // Headlines and Display: Prestigious Editorial Serif (Newsreader)
    final textTheme = sansTextTheme.copyWith(
      displayLarge: GoogleFonts.newsreader(
        fontSize: 56,
        fontWeight: FontWeight.w600,
        letterSpacing: -1.4,
        height: 1.12,
        color: colorScheme.onSurface,
      ),
      displayMedium: GoogleFonts.newsreader(
        fontSize: 44,
        fontWeight: FontWeight.w600,
        letterSpacing: -1.1,
        height: 1.15,
        color: colorScheme.onSurface,
      ),
      displaySmall: GoogleFonts.newsreader(
        fontSize: 36,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.8,
        height: 1.18,
        color: colorScheme.onSurface,
      ),
      headlineLarge: GoogleFonts.newsreader(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.6,
        height: 1.2,
        color: colorScheme.onSurface,
      ),
      headlineMedium: GoogleFonts.newsreader(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        height: 1.25,
        color: colorScheme.onSurface,
      ),
      headlineSmall: sansTextTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: colorScheme.onSurface,
      ),
      titleLarge: sansTextTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: colorScheme.onSurface,
      ),
      titleMedium: sansTextTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      bodyLarge: sansTextTheme.bodyLarge?.copyWith(
        fontSize: 16,
        height: 1.6,
        color: appColors.mutedText,
      ),
      bodyMedium: sansTextTheme.bodyMedium?.copyWith(
        fontSize: 14,
        height: 1.5,
        color: appColors.mutedText,
      ),
      labelLarge: sansTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
    ).apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );

    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: appColors.background,
      textTheme: textTheme,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: appColors.surfaceAlt,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: appColors.border),
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w500,
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
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: appColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: appColors.cardBorder, width: 1.0),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: isDark ? const Color(0xFFFAF9F5) : const Color(0xFF141413),
          foregroundColor: isDark ? const Color(0xFF141413) : const Color(0xFFFAF9F5),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          side: BorderSide(color: appColors.border, width: 1.0),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: appColors.surfaceAlt,
        hintStyle: textTheme.bodyMedium?.copyWith(color: appColors.subtleText),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: appColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: appColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[appColors],
    );
  }
}

extension AppThemeContext on BuildContext {
  ThemeData get appTheme => Theme.of(this);
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
  ColorScheme get scheme => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  // Convenient Claude Editorial Serif typography helpers
  TextStyle serifDisplay({
    double fontSize = 48,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    double letterSpacing = -1.2,
    double height = 1.15,
  }) {
    return GoogleFonts.newsreader(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      color: color ?? scheme.onSurface,
    );
  }

  TextStyle serifHeadline({
    double fontSize = 28,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    double letterSpacing = -0.6,
    double height = 1.25,
  }) {
    return GoogleFonts.newsreader(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      color: color ?? scheme.onSurface,
    );
  }
}

