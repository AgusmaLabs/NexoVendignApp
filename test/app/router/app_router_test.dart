import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vendingapp/app/app.dart';
import 'package:vendingapp/app/home/initial_page.dart';
import 'package:vendingapp/app/home/unknown_route_page.dart';
import 'package:vendingapp/app/router/app_router.dart';

import '../../support/test_doubles.dart';

void main() {
  group('AppRouter', () {
    test('home path is /', () {
      expect(AppRouter.homePath, '/');
    });

    testWidgets('initial navigation renders InitialPage', (tester) async {
      await tester.pumpWidget(VendingApp(dependencies: testDependencies()));
      await tester.pumpAndSettle();

      expect(find.byType(InitialPage), findsOneWidget);
      expect(find.text('VendingApp'), findsWidgets);
    });

    testWidgets('unknown route renders UnknownRoutePage', (tester) async {
      await tester.pumpWidget(VendingApp(dependencies: testDependencies()));
      await tester.pumpAndSettle();

      final navigator = Navigator.of(tester.element(find.byType(InitialPage)));
      navigator.pushNamed('/does-not-exist');
      await tester.pumpAndSettle();

      expect(find.byType(UnknownRoutePage), findsOneWidget);
      expect(find.textContaining('does-not-exist'), findsOneWidget);
    });
  });
}
