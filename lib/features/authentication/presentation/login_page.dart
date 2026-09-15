import 'package:flutter/material.dart';

import '../../../app/bootstrap/app_dependencies.dart';
import '../application/authentication_controller.dart';
import '../application/authentication_state.dart';

/// Google Sign-In + NexoVending session screen. Never displays tokens.
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
                final isLoading = authController.isBusy;

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
                      Text(
                        _loadingLabel(state),
                        style: theme.textTheme.bodyMedium,
                      ),
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

  String _loadingLabel(AuthenticationState state) {
    return switch (state) {
      RestoringSession() => 'Restaurando sesión...',
      CreatingSession() => 'Iniciando sesión...',
      Authenticating() => 'Authenticating',
      _ => 'Cargando...',
    };
  }

  List<Widget> _statusWidgets(ThemeData theme, AuthenticationState state) {
    return switch (state) {
      Authenticated() => const <Widget>[],
      SessionExpired() => [
        Text(
          'La sesión ha expirado. Vuelve a iniciar sesión.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
          textAlign: TextAlign.center,
        ),
      ],
      SessionFailure(:final message) ||
      AuthenticationFailure(:final message) => [
        Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
          textAlign: TextAlign.center,
        ),
      ],
      Unauthenticated() ||
      Authenticating() ||
      CreatingSession() ||
      RestoringSession() => const <Widget>[],
    };
  }
}
