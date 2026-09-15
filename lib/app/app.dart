import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import 'bootstrap/app_dependencies.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// Application shell that composes theme, router, and configuration.
///
/// Business workflows must not live here.
class VendingApp extends StatelessWidget {
  const VendingApp({required this.dependencies, super.key});

  final AppDependencies dependencies;

  AppConfig get config => dependencies.config;

  @override
  Widget build(BuildContext context) {
    return AppDependenciesScope(
      dependencies: dependencies,
      child: AppConfigScope(
        config: dependencies.config,
        child: MaterialApp(
          title: 'VendingApp',
          theme: AppTheme.light(),
          navigatorKey: dependencies.navigatorKey,
          initialRoute: AppRouter.loginPath,
          onGenerateRoute: AppRouter.onGenerateRoute,
        ),
      ),
    );
  }
}
