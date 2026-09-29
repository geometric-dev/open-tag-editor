import 'package:flutter/material.dart';

/// Application theme configuration tuned for a desktop-native feel.
///
/// Uses each platform's default system font, compact density, small border radii,
/// and restrained Material styling to avoid the "generic mobile app" look.
class AppTheme {
  AppTheme._();

  // No explicit fontFamily: Flutter maps to the platform default
  // (Segoe UI on Windows, San Francisco on macOS, Roboto/Cantarell on
  // Linux), keeping the desktop-native feel without a Windows-only font.
  static const _seedColor = Color(0xFF1565C0);

  /// Visual density for a compact desktop layout.
  static const _density = VisualDensity(horizontal: -2, vertical: -2);

  static ThemeData get light => _buildTheme(
    ColorScheme.fromSeed(seedColor: _seedColor, brightness: Brightness.light),
  );

  static ThemeData get dark => _buildTheme(
    ColorScheme.fromSeed(seedColor: _seedColor, brightness: Brightness.dark),
  );

  /// High-contrast variants.
  ///
  /// The default scheme is derived from a seed colour, which produces
  /// mid-tone surfaces and outlines. On a low-quality monitor, or for a user
  /// with reduced contrast sensitivity, those borders and the text on them
  /// are hard to resolve. These builds push surfaces to the extremes and
  /// darken the outlines so edges are unambiguous.
  static ThemeData get highContrastLight =>
      _buildTheme(_highContrast(Brightness.light), highContrast: true);

  static ThemeData get highContrastDark =>
      _buildTheme(_highContrast(Brightness.dark), highContrast: true);

  /// Builds a scheme with maximal surface/foreground separation.
  static ColorScheme _highContrast(Brightness brightness) {
    final base = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    );
    final isLight = brightness == Brightness.light;

    return base.copyWith(
      // Push the surfaces apart instead of letting the tonal palette sit
      // them close together.
      surface: isLight ? Colors.white : Colors.black,
      onSurface: isLight ? Colors.black : Colors.white,
      surfaceContainerLowest: isLight ? Colors.white : Colors.black,
      surfaceContainerLow: isLight ? Colors.white : const Color(0xFF0A0A0A),
      surfaceContainer: isLight
          ? const Color(0xFFF2F2F2)
          : const Color(0xFF121212),
      surfaceContainerHigh: isLight
          ? const Color(0xFFE6E6E6)
          : const Color(0xFF1C1C1C),
      surfaceContainerHighest: isLight
          ? const Color(0xFFD9D9D9)
          : const Color(0xFF262626),
      // Outlines carry the structure here, so make them unambiguous rather
      // than tonal.
      outline: isLight ? Colors.black : Colors.white,
      outlineVariant: isLight
          ? const Color(0xFF555555)
          : const Color(0xFFAAAAAA),
    );
  }

  static ThemeData _buildTheme(
    ColorScheme colorScheme, {
    bool highContrast = false,
  }) {
    final isLight = colorScheme.brightness == Brightness.light;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      visualDensity: _density,
      // --- AppBar: flat, no elevation, system-like ---
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      // --- Cards: minimal elevation, tight radius ---
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      // --- Inputs: tight, small radius, system-like borders ---
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(3)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        filled: true,
        fillColor: isLight
            ? colorScheme.surface
            : colorScheme.surfaceContainerLowest,
      ),
      // --- Data table: compact rows ---
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(
          colorScheme.surfaceContainerHighest,
        ),
        dataRowMinHeight: 28,
        dataRowMaxHeight: 36,
        headingRowHeight: 32,
      ),
      // --- Checkboxes: small, square-ish ---
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: _density,
      ),
      // --- Buttons: compact, small radius ---
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(72, 30),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: const TextStyle(fontSize: 13),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(64, 30),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: const TextStyle(fontSize: 13),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(72, 30),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: const TextStyle(fontSize: 13),
        ),
      ),
      // --- IconButtons: compact ---
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(28, 28),
          padding: const EdgeInsets.all(4),
        ),
      ),
      // --- Dialogs: tight radius, no excessive rounding ---
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        titleTextStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      // --- Dropdown menus: tight ---
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(3)),
        ),
      ),
      // --- Tooltips: simple, no excessive padding ---
      tooltipTheme: TooltipThemeData(
        textStyle: TextStyle(
          fontSize: 12,
          color: isLight ? Colors.white : colorScheme.onSurface,
        ),
        decoration: BoxDecoration(
          color: isLight
              ? colorScheme.inverseSurface
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
        ),
        waitDuration: const Duration(milliseconds: 500),
      ),
      // --- Scrollbar: thin, always visible on desktop ---
      scrollbarTheme: const ScrollbarThemeData(
        thickness: WidgetStatePropertyAll(8),
        radius: Radius.circular(4),
        thumbVisibility: WidgetStatePropertyAll(true),
      ),
      // --- Dividers ---
      // Heavier when high contrast is on: the default relies on a 1px tonal
      // line, which is exactly what a low-contrast screen cannot resolve.
      dividerTheme: DividerThemeData(
        thickness: highContrast ? 2 : 1,
        space: highContrast ? 2 : 1,
        color: highContrast ? colorScheme.outline : colorScheme.outlineVariant,
      ),
      // --- Snackbar: compact ---
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }
}
