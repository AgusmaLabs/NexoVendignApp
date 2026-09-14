import 'package:flutter/material.dart';

import '../home/initial_page.dart';
import '../home/unknown_route_page.dart';

/// Centralized navigation for VendingApp.
///
/// Future routes should be registered here without changing the shell
/// composition in [VendingApp].
abstract final class AppRouter {
  static const String homePath = '/';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case homePath:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const InitialPage(),
        );
      default:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) =>
              UnknownRoutePage(routeName: settings.name, homePath: homePath),
        );
    }
  }
}
