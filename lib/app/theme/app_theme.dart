import 'package:flutter/material.dart';

/// Centralized visual theme for VendingApp.
///
/// Features must not introduce their own global [ThemeData].
abstract final class AppTheme {
  static const Color _seedColor = Color(0xFF0F6B4C);

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.light,
      visualDensity: VisualDensity.standard,
      typography: Typography.material2021(platform: TargetPlatform.android),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      scaffoldBackgroundColor: colorScheme.surface,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
    );
  }
}
