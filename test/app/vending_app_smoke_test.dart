import 'package:flutter_test/flutter_test.dart';
import 'package:vendingapp/app/app.dart';
import 'package:vendingapp/app/home/initial_page.dart';

import '../support/test_doubles.dart';

/// Smoke test: application shell boots and renders without exceptions.
void main() {
  testWidgets('VendingApp smoke: boot → initial render', (tester) async {
    await tester.pumpWidget(VendingApp(dependencies: testDependencies()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(VendingApp), findsOneWidget);
    expect(find.byType(InitialPage), findsOneWidget);
    expect(find.textContaining('Foundation shell'), findsOneWidget);
  });
}
