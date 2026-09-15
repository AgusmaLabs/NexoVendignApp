import 'package:flutter/material.dart';

import '../../features/authentication/presentation/auth_gate.dart';
import '../../features/machine/presentation/identify_machine_page.dart';
import '../bootstrap/app_dependencies.dart';
import '../home/unknown_route_page.dart';

/// Centralized navigation for VendingApp.
///
/// Future routes should be registered here without changing the shell
/// composition in [VendingApp].
abstract final class AppRouter {
  static const String homePath = '/';
  static const String loginPath = '/login';
  static const String identifyMachinePath = '/machines/identify';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case homePath:
      case loginPath:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const AuthGate(),
        );
      case identifyMachinePath:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) {
            final deps = AppDependenciesScope.of(context);
            return IdentifyMachinePage(
              controller: deps.machineIdentificationController,
              onSignOut: () {
                deps.machineIdentificationController.clear();
                deps.operatorBootstrapController.clear();
                deps.authenticationController.signOut();
                Navigator.of(context)
                    .pushNamedAndRemoveUntil(loginPath, (_) => false);
              },
            );
          },
        );
      default:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) =>
              UnknownRoutePage(routeName: settings.name, homePath: loginPath),
        );
    }
  }
}
