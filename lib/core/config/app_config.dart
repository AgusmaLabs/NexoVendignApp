import 'package:flutter/widgets.dart';

/// Deployment environments supported by VendingApp.
enum AppEnvironment { development, staging, production }

/// Application configuration provided externally to the UI.
///
/// Values must not be hardcoded inside widgets or feature modules.
final class AppConfig {
  AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.tenantId,
    this.httpTimeout = const Duration(seconds: 30),
  }) {
    if (apiBaseUrl.trim().isEmpty) {
      throw ArgumentError.value(apiBaseUrl, 'apiBaseUrl', 'must not be empty');
    }
    if (tenantId.trim().isEmpty) {
      throw ArgumentError.value(tenantId, 'tenantId', 'must not be empty');
    }
    if (httpTimeout <= Duration.zero) {
      throw ArgumentError.value(
        httpTimeout,
        'httpTimeout',
        'must be greater than zero',
      );
    }
  }

  final AppEnvironment environment;
  final String apiBaseUrl;

  /// Tenant used only when creating a session (`POST /auth/session`).
  ///
  /// After the session JWT is issued, tenant authority comes from the token —
  /// not from this config field on business calls.
  final String tenantId;
  final Duration httpTimeout;
}

/// Exposes [AppConfig] to the widget tree without hardcoding values in UI.
final class AppConfigScope extends InheritedWidget {
  const AppConfigScope({required this.config, required super.child, super.key});

  final AppConfig config;

  static AppConfig of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppConfigScope>();
    assert(scope != null, 'AppConfigScope not found in the widget tree');
    return scope!.config;
  }

  @override
  bool updateShouldNotify(AppConfigScope oldWidget) {
    return config.environment != oldWidget.config.environment ||
        config.apiBaseUrl != oldWidget.config.apiBaseUrl ||
        config.tenantId != oldWidget.config.tenantId ||
        config.httpTimeout != oldWidget.config.httpTimeout;
  }
}
