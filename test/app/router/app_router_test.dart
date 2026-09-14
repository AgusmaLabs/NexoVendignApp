import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vendingapp/app/app.dart';
import 'package:vendingapp/app/home/initial_page.dart';
import 'package:vendingapp/app/home/unknown_route_page.dart';
import 'package:vendingapp/app/router/app_router.dart';
import 'package:vendingapp/core/config/app_config.dart';

void main() {
  AppConfig buildConfig() {
    return AppConfig(
      environment: AppEnvironment.development,
      apiBaseUrl: 'http://localhost:8080',
    );
  }

  group('AppRouter', () {
    test('home path is /', () {
      expect(AppRouter.homePath, '/');
    });

    testWidgets('initial navigation renders InitialPage', (tester) async {
      await tester.pumpWidget(VendingApp(config: buildConfig()));
      await tester.pumpAndSettle();

      expect(find.byType(InitialPage), findsOneWidget);
      expect(find.text('VendingApp'), findsWidgets);
    });

    testWidgets('unknown route renders UnknownRoutePage', (tester) async {
      await tester.pumpWidget(VendingApp(config: buildConfig()));
      await tester.pumpAndSettle();

      final navigator = Navigator.of(tester.element(find.byType(InitialPage)));
      navigator.pushNamed('/does-not-exist');
      await tester.pumpAndSettle();

      expect(find.byType(UnknownRoutePage), findsOneWidget);
      expect(find.textContaining('does-not-exist'), findsOneWidget);
    });
  });
}
