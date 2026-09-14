import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';

/// Minimal placeholder screen used to verify the application shell.
///
/// Contains no vending business logic.
class InitialPage extends StatelessWidget {
  const InitialPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = AppConfigScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('VendingApp')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'VendingApp',
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Foundation shell — business features arrive in later commits.',
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Text(
                'Environment: ${config.environment.name}',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
