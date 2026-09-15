import 'package:flutter/material.dart';

import '../../../app/bootstrap/app_dependencies.dart';
import '../../../app/router/app_router.dart';
import '../../machine/domain/machine.dart';
import '../application/replenishment_creation_controller.dart';
import '../application/replenishment_creation_state.dart';
import '../domain/replenishment.dart';

/// Starts a replenishment session for the currently identified machine.
class ReplenishmentStartPage extends StatelessWidget {
  const ReplenishmentStartPage({
    super.key,
    this.controller,
    this.machine,
    this.onSignOut,
  });

  final ReplenishmentCreationController? controller;
  final Machine? machine;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final resolvedController = controller;
    final Machine? resolvedMachine;
    final ReplenishmentCreationController effectiveController;
    if (resolvedController != null) {
      effectiveController = resolvedController;
      resolvedMachine = machine;
    } else {
      final deps = AppDependenciesScope.of(context);
      effectiveController = deps.replenishmentCreationController;
      resolvedMachine =
          machine ?? deps.machineIdentificationController.currentMachine;
    }

    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: effectiveController,
      builder: (context, _) {
        final state = effectiveController.state;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Reposición'),
            actions: [
              if (onSignOut != null)
                TextButton(
                  onPressed: onSignOut,
                  child: const Text('Salir'),
                ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: switch (state) {
                ReplenishmentCreationCreated(:final replenishment) =>
                  _CreatedView(
                    theme: theme,
                    machine: resolvedMachine,
                    replenishment: replenishment,
                  ),
                ReplenishmentCreationSessionExpired() => Center(
                  child: Text(
                    'La sesión ha expirado. Vuelve a iniciar sesión.',
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
                ReplenishmentCreationNoMachine() => _MessageView(
                  theme: theme,
                  message:
                      'Identifica una máquina antes de iniciar la reposición.',
                  actionLabel: 'Identificar máquina',
                  onAction: () {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      AppRouter.identifyMachinePath,
                      (route) => route.isFirst,
                    );
                  },
                ),
                ReplenishmentCreationNoOperator() => _MessageView(
                  theme: theme,
                  message: 'No hay un operador Vending válido.',
                ),
                ReplenishmentCreationFailure(:final message, :final canRetry) =>
                  _MessageView(
                    theme: theme,
                    message: message,
                    actionLabel: canRetry ? 'Reintentar' : null,
                    onAction: canRetry ? effectiveController.retry : null,
                    error: true,
                  ),
                _ => _ReadyView(
                  theme: theme,
                  machine: resolvedMachine,
                  isCreating: effectiveController.isCreating,
                  onStart: effectiveController.start,
                ),
              },
            ),
          ),
        );
      },
    );
  }
}

class _ReadyView extends StatelessWidget {
  const _ReadyView({
    required this.theme,
    required this.machine,
    required this.isCreating,
    required this.onStart,
  });

  final ThemeData theme;
  final Machine? machine;
  final bool isCreating;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    if (machine == null) {
      return _MessageView(
        theme: theme,
        message: 'Identifica una máquina antes de iniciar la reposición.',
        actionLabel: 'Identificar máquina',
        onAction: () {
          Navigator.of(context).pushNamedAndRemoveUntil(
            AppRouter.identifyMachinePath,
            (route) => route.isFirst,
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Máquina', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(machine!.name, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(machine!.identifier, style: theme.textTheme.bodyLarge),
        Text(
          '${machine!.machineType} · ${machine!.status}',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 32),
        Text(
          isCreating ? 'Creando reposición...' : 'Listo para reponer',
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        if (isCreating)
          const Center(child: CircularProgressIndicator())
        else
          FilledButton(
            onPressed: onStart,
            child: const Text('Iniciar reposición'),
          ),
      ],
    );
  }
}

class _CreatedView extends StatelessWidget {
  const _CreatedView({
    required this.theme,
    required this.machine,
    required this.replenishment,
  });

  final ThemeData theme;
  final Machine? machine;
  final Replenishment replenishment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Reposición iniciada',
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        if (machine != null) ...[
          Text(machine!.name, style: theme.textTheme.titleLarge),
          Text(machine!.identifier, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 12),
        ],
        Text('Estado: ${replenishment.status}'),
        Text('ID: ${replenishment.id}'),
        const SizedBox(height: 24),
        Text(
          'Lista para agregar productos.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pushNamed(AppRouter.productLookupPath);
          },
          child: const Text('Escanear producto'),
        ),
      ],
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.theme,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.error = false,
  });

  final ThemeData theme;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            message,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: error ? theme.colorScheme.error : null,
            ),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
