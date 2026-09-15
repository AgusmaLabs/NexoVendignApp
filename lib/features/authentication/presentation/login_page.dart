import 'package:flutter/material.dart';

import '../../../app/bootstrap/app_dependencies.dart';
import '../application/authentication_controller.dart';
import '../application/authentication_state.dart';

/// Minimal Google Sign-In screen. Never displays or logs `id_token`.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key, this.controller});

  /// Optional override for tests. Defaults to [AppDependencies] composition.
  final AuthenticationController? controller;

  @override
  Widget build(BuildContext context) {
    final authController =
        controller ?? AppDependenciesScope.of(context).authenticationController;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ListenableBuilder(
              listenable: authController,
              builder: (context, _) {
                final state = authController.state;
                final isLoading = state is Authenticating;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'VendingApp',
                      style: theme.textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Inicia sesión para continuar',
                      style: theme.textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    if (isLoading) ...[
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text('Authenticating', style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 24),
                    ],
                    FilledButton(
                      onPressed: isLoading ? null : authController.signIn,
                      child: const Text('Continuar con Google'),
                    ),
                    const SizedBox(height: 24),
                    ..._statusWidgets(theme, state),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _statusWidgets(ThemeData theme, AuthenticationState state) {
    return switch (state) {
      Authenticated(:final result) => [
        Text(
          'Autenticado con Google',
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        if (result.email != null) ...[
          const SizedBox(height: 8),
          Text(
            result.email!,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'Sesión NexoVending pendiente (Commit 4).',
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
      AuthenticationFailure(:final message) => [
        Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
          textAlign: TextAlign.center,
        ),
      ],
      Unauthenticated() || Authenticating() => const <Widget>[],
    };
  }
}
