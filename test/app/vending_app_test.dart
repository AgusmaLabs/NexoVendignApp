import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vendingapp/app/app.dart';
import 'package:vendingapp/app/bootstrap/app_dependencies.dart';
import 'package:vendingapp/app/theme/app_theme.dart';
import 'package:vendingapp/core/config/app_config.dart';
import 'package:vendingapp/features/authentication/presentation/login_page.dart';

import '../support/test_doubles.dart';

void main() {
  group('VendingApp', () {
    testWidgets('can be constructed and starts on the login route', (
      tester,
    ) async {
      await tester.pumpWidget(VendingApp(dependencies: testDependencies()));
      await tester.pumpAndSettle();

      expect(find.byType(VendingApp), findsOneWidget);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('uses AppTheme ColorScheme', (tester) async {
      await tester.pumpWidget(VendingApp(dependencies: testDependencies()));
      await tester.pumpAndSettle();

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      final expected = AppTheme.light();

      expect(materialApp.theme, isNotNull);
      expect(
        materialApp.theme!.colorScheme.primary,
        expected.colorScheme.primary,
      );
    });

    testWidgets('injects AppConfig without hardcoding values in the UI', (
      tester,
    ) async {
      final dependencies = testDependencies(
        config: AppConfig(
          environment: AppEnvironment.staging,
          apiBaseUrl: 'https://staging.example.com',
        ),
      );

      await tester.pumpWidget(VendingApp(dependencies: dependencies));
      await tester.pumpAndSettle();

      final scopedConfig = AppConfigScope.of(
        tester.element(find.byType(LoginPage)),
      );
      expect(scopedConfig.apiBaseUrl, 'https://staging.example.com');
      expect(scopedConfig.environment, AppEnvironment.staging);

      final scopedDeps = AppDependenciesScope.of(
        tester.element(find.byType(LoginPage)),
      );
      expect(scopedDeps.config.apiBaseUrl, 'https://staging.example.com');
    });
  });
}
