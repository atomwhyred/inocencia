import 'package:flutter/material.dart';

/// Paleta de inocencIA.
class AppColors {
  static const blue = Color(0xFF0035AD);
  static const red = Color(0xFFDC241F);
  static const white = Color(0xFFFFFFFF);

  /// Fondo del modo oscuro.
  static const night = Color(0xFF272757);
}

/// Temas claro y oscuro: esquinas redondeadas y objetivos tactiles grandes para
/// ninos. Los esquemas se definen a mano para respetar los colores de marca.
class AppTheme {
  /// Modo claro: base blanca, azul como color principal y rojo de acento.
  static const lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.blue,
    onPrimary: AppColors.white,
    primaryContainer: Color(0xFFDCE4FF),
    onPrimaryContainer: Color(0xFF001551),
    secondary: AppColors.red,
    onSecondary: AppColors.white,
    secondaryContainer: Color(0xFFFFDAD6),
    onSecondaryContainer: Color(0xFF410002),
    tertiary: Color(0xFF3F5FB8),
    onTertiary: AppColors.white,
    tertiaryContainer: Color(0xFFDCE4FF),
    onTertiaryContainer: Color(0xFF00164F),
    error: Color(0xFFBA1A1A),
    onError: AppColors.white,
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: AppColors.white,
    onSurface: Color(0xFF1B1B23),
    onSurfaceVariant: Color(0xFF44464F),
    surfaceContainerLowest: AppColors.white,
    surfaceContainerLow: Color(0xFFF4F6FB),
    surfaceContainer: Color(0xFFEDF0F8),
    surfaceContainerHigh: Color(0xFFE6EAF4),
    surfaceContainerHighest: Color(0xFFDFE4F0),
    outline: Color(0xFF757780),
    outlineVariant: Color(0xFFC5C6D0),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF303038),
    onInverseSurface: Color(0xFFF1F0FA),
    inversePrimary: Color(0xFFB6C4FF),
  );

  /// Modo oscuro: fondo #272757. El azul y el rojo de marca quedan como
  /// contenedores; el texto y los botones usan tonos mas claros para que se lean.
  static const darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFB6C4FF),
    onPrimary: Color(0xFF002A78),
    primaryContainer: AppColors.blue,
    onPrimaryContainer: AppColors.white,
    secondary: Color(0xFFFFB3AD),
    onSecondary: Color(0xFF680008),
    secondaryContainer: AppColors.red,
    onSecondaryContainer: AppColors.white,
    tertiary: Color(0xFFB6C4FF),
    onTertiary: Color(0xFF002A78),
    tertiaryContainer: Color(0xFF3D3D80),
    onTertiaryContainer: Color(0xFFDCE1FF),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: AppColors.night,
    onSurface: Color(0xFFE4E1F0),
    onSurfaceVariant: Color(0xFFC8C5D8),
    surfaceContainerLowest: Color(0xFF1E1E45),
    surfaceContainerLow: Color(0xFF2D2D61),
    surfaceContainer: Color(0xFF32326A),
    surfaceContainerHigh: Color(0xFF3A3A74),
    surfaceContainerHighest: Color(0xFF43437E),
    outline: Color(0xFF928FA3),
    outlineVariant: Color(0xFF4A4A80),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFE4E1F0),
    onInverseSurface: Color(0xFF303038),
    inversePrimary: AppColors.blue,
  );

  /// Modo Bateria / Apagon: negro puro (las pantallas AMOLED apagan esos pixeles)
  /// y contraste alto. Sale del esquema oscuro con las superficies en negro.
  static final saverScheme = darkScheme.copyWith(
    surface: const Color(0xFF000000),
    surfaceContainerLowest: const Color(0xFF000000),
    surfaceContainerLow: const Color(0xFF101010),
    surfaceContainer: const Color(0xFF151515),
    surfaceContainerHigh: const Color(0xFF1C1C1C),
    surfaceContainerHighest: const Color(0xFF242424),
    onSurface: const Color(0xFFFFFFFF),
    onSurfaceVariant: const Color(0xFFE0E0E0),
    outline: const Color(0xFFB0B0B0),
    outlineVariant: const Color(0xFF404040),
    tertiaryContainer: const Color(0xFF1F1F3D),
    primaryContainer: const Color(0xFF0A2A8C),
  );

  static ThemeData light() => _build(lightScheme);
  static ThemeData saver() => _build(saverScheme);
  static ThemeData dark() => _build(darkScheme);

  static ThemeData _build(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          // Igual que el boton relleno: Buscar y Detectar se ven del mismo tamano.
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.primaryContainer,
      ),
    );
  }
}
