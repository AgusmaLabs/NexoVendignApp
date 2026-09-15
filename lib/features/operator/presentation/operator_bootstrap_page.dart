import 'package:flutter/material.dart';

import '../../../app/bootstrap/app_dependencies.dart';
import '../../../app/router/app_router.dart';
import '../application/operator_bootstrap_controller.dart';
import '../application/operator_bootstrap_state.dart';
import '../domain/operator.dart';

/// Minimal shell after operator bootstrap succeeds.
class OperatorHomePage extends StatelessWidget {
  const OperatorHomePage({
    required this.operator,
    this.onSignOut,
    this.onIdentifyMachine,
    super.key,
  });

  final Operator operator;
  final VoidCallback? onSignOut;
  final VoidCallback? onIdentifyMachine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Bienvenido, ${operator.welcomeName}',
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Operador listo. Identifica una máquina para continuar.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed:
                      onIdentifyMachine ??
                      () {
                        Navigator.of(context)
                            .pushNamed(AppRouter.identifyMachinePath);
                      },
                  child: const Text('Identificar máquina'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: onSignOut,
                  child: const Text('Cerrar sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bootstrap UI: loading, errors with retry, or [OperatorHomePage].
class OperatorBootstrapPage extends StatefulWidget {
  const OperatorBootstrapPage({
    super.key,
    this.controller,
    this.onSignOut,
    this.autoLoad = true,
  });

  final OperatorBootstrapController? controller;
  final VoidCallback? onSignOut;
  final bool autoLoad;

  @override
  State<OperatorBootstrapPage> createState() => _OperatorBootstrapPageState();
}

class _OperatorBootstrapPageState extends State<OperatorBootstrapPage> {
  @override
  void initState() {
    super.initState();
    if (widget.autoLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final controller =
            widget.controller ??
            AppDependenciesScope.of(context).operatorBootstrapController;
        if (controller.state is OperatorBootstrapUnknown) {
          controller.load();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller =
        widget.controller ??
        AppDependenciesScope.of(context).operatorBootstrapController;
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.state;
        return switch (state) {
          OperatorBootstrapLoaded(:final operator) => OperatorHomePage(
            operator: operator,
            onSignOut: widget.onSignOut,
          ),
          OperatorBootstrapLoading() || OperatorBootstrapUnknown() => Scaffold(
            body: SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Cargando operador...',
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
          ),
          OperatorBootstrapAccessDenied(:final message) => _ErrorScaffold(
            message: message,
            theme: theme,
            onRetry: null,
            onSignOut: widget.onSignOut,
          ),
          OperatorBootstrapNotConfigured(:final message) => _ErrorScaffold(
            message: message,
            theme: theme,
            onRetry: null,
            onSignOut: widget.onSignOut,
          ),
          OperatorBootstrapFailure(:final message, :final canRetry) =>
            _ErrorScaffold(
              message: message,
              theme: theme,
              onRetry: canRetry ? controller.retry : null,
              onSignOut: widget.onSignOut,
            ),
          OperatorBootstrapSessionExpired() => Scaffold(
            body: SafeArea(
              child: Center(
                child: Text(
                  'La sesión ha expirado. Vuelve a iniciar sesión.',
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        };
      },
    );
  }
}

class _ErrorScaffold extends StatelessWidget {
  const _ErrorScaffold({
    required this.message,
    required this.theme,
    required this.onRetry,
    required this.onSignOut,
  });

  final String message;
  final ThemeData theme;
  final VoidCallback? onRetry;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  message,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: onRetry,
                    child: const Text('Reintentar'),
                  ),
                ],
                if (onSignOut != null) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: onSignOut,
                    child: const Text('Cerrar sesión'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
