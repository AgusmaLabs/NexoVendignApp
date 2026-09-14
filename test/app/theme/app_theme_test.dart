import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vendingapp/app/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('builds a ThemeData with a ColorScheme', () {
      final theme = AppTheme.light();

      expect(theme, isA<ThemeData>());
      expect(theme.colorScheme, isA<ColorScheme>());
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.light);
    });
  });
}
