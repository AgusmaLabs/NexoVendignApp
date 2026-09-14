import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// Application shell that composes theme, router, and configuration.
///
/// Business workflows must not live here.
class VendingApp extends StatelessWidget {
  const VendingApp({required this.config, super.key});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return AppConfigScope(
      config: config,
      child: MaterialApp(
        title: 'VendingApp',
        theme: AppTheme.light(),
        initialRoute: AppRouter.homePath,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
  }
}
