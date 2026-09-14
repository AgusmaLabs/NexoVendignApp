import 'package:flutter/material.dart';

/// Shown when navigation targets a route that is not registered.
class UnknownRoutePage extends StatelessWidget {
  const UnknownRoutePage({
    required this.routeName,
    this.homePath = '/',
    super.key,
  });

  final String? routeName;
  final String homePath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = routeName ?? '(null)';

    return Scaffold(
      appBar: AppBar(title: const Text('Route not found')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'No route registered for "$displayName".',
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil(homePath, (route) => false);
                },
                child: const Text('Go home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
