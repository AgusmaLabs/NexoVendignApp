import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vendingapp/app/app.dart';
import 'package:vendingapp/app/home/initial_page.dart';
import 'package:vendingapp/app/theme/app_theme.dart';
import 'package:vendingapp/core/config/app_config.dart';

void main() {
  AppConfig buildConfig({
    AppEnvironment environment = AppEnvironment.development,
    String apiBaseUrl = 'http://localhost:8080',
  }) {
    return AppConfig(environment: environment, apiBaseUrl: apiBaseUrl);
  }

  group('VendingApp', () {
    testWidgets('can be constructed and starts on the initial route', (
      tester,
    ) async {
      await tester.pumpWidget(VendingApp(config: buildConfig()));
      await tester.pumpAndSettle();

      expect(find.byType(VendingApp), findsOneWidget);
      expect(find.byType(InitialPage), findsOneWidget);
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('uses AppTheme ColorScheme', (tester) async {
      await tester.pumpWidget(VendingApp(config: buildConfig()));
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
      final config = buildConfig(
        environment: AppEnvironment.staging,
        apiBaseUrl: 'https://staging.example.com',
      );

      await tester.pumpWidget(VendingApp(config: config));
      await tester.pumpAndSettle();

      expect(find.text('Environment: staging'), findsOneWidget);

      final scoped = AppConfigScope.of(
        tester.element(find.byType(InitialPage)),
      );
      expect(scoped.apiBaseUrl, 'https://staging.example.com');
      expect(scoped.environment, AppEnvironment.staging);
    });
  });
}
