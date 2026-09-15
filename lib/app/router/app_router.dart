import 'package:flutter/material.dart';

import '../../features/authentication/presentation/auth_gate.dart';
import '../../features/machine/presentation/identify_machine_page.dart';
import '../../features/machine/presentation/machine_detail_page.dart';
import '../../features/replenishment/presentation/replenishment_start_page.dart';
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
  static const String machineDetailPath = '/machines/detail';
  static const String replenishmentStartPath = '/replenishments/start';

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
              onSignOut: () => _signOut(context, deps),
            );
          },
        );
      case machineDetailPath:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) {
            final deps = AppDependenciesScope.of(context);
            final machineId =
                settings.arguments as String? ??
                deps.machineIdentificationController.currentMachine?.machineId;
            if (machineId == null || machineId.trim().isEmpty) {
              return const UnknownRoutePage(
                routeName: machineDetailPath,
                homePath: identifyMachinePath,
              );
            }
            return MachineDetailPage(
              machineId: machineId,
              controller: deps.machineDetailController,
              onSignOut: () => _signOut(context, deps),
            );
          },
        );
      case replenishmentStartPath:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) {
            final deps = AppDependenciesScope.of(context);
            return ReplenishmentStartPage(
              controller: deps.replenishmentCreationController,
              machine: deps.machineIdentificationController.currentMachine,
              onSignOut: () => _signOut(context, deps),
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

  static void _signOut(BuildContext context, AppDependencies deps) {
    deps.replenishmentCreationController.clear();
    deps.machineDetailController.clear();
    deps.machineIdentificationController.clear();
    deps.operatorBootstrapController.clear();
    deps.authenticationController.signOut();
    Navigator.of(context).pushNamedAndRemoveUntil(loginPath, (_) => false);
  }
}
