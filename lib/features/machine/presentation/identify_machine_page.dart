import 'package:flutter/material.dart';

import '../../../app/bootstrap/app_dependencies.dart';
import '../application/machine_identification_controller.dart';
import '../application/machine_identification_state.dart';

/// Minimal screen to resolve a machine by identifier.
class IdentifyMachinePage extends StatefulWidget {
  const IdentifyMachinePage({super.key, this.controller, this.onSignOut});

  final MachineIdentificationController? controller;
  final VoidCallback? onSignOut;

  @override
  State<IdentifyMachinePage> createState() => _IdentifyMachinePageState();
}

class _IdentifyMachinePageState extends State<IdentifyMachinePage> {
  late final TextEditingController _identifierController;

  @override
  void initState() {
    super.initState();
    _identifierController = TextEditingController();
  }

  @override
  void dispose() {
    _identifierController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller =
        widget.controller ??
        AppDependenciesScope.of(context).machineIdentificationController;
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.state;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Máquina'),
            actions: [
              if (widget.onSignOut != null)
                TextButton(
                  onPressed: widget.onSignOut,
                  child: const Text('Salir'),
                ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: switch (state) {
                MachineIdentificationResolved(:final machine) => _ResolvedView(
                  theme: theme,
                  name: machine.name,
                  identifier: machine.identifier,
                  machineType: machine.machineType,
                  status: machine.status,
                  onContinue: () {
                    Navigator.of(context).pushNamed(
                      '/machines/detail',
                      arguments: machine.machineId,
                    );
                  },
                  onIdentifyAnother: () {
                    _identifierController.clear();
                    controller.resetToInitial();
                  },
                ),
                MachineIdentificationSessionExpired() => Center(
                  child: Text(
                    'La sesión ha expirado. Vuelve a iniciar sesión.',
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
                _ => _IdentifyForm(
                  theme: theme,
                  identifierController: _identifierController,
                  state: state,
                  isResolving: controller.isResolving,
                  onIdentify: () =>
                      controller.identify(_identifierController.text),
                  onRetry: controller.retry,
                ),
              },
            ),
          ),
        );
      },
    );
  }
}

class _IdentifyForm extends StatelessWidget {
  const _IdentifyForm({
    required this.theme,
    required this.identifierController,
    required this.state,
    required this.isResolving,
    required this.onIdentify,
    required this.onRetry,
  });

  final ThemeData theme;
  final TextEditingController identifierController;
  final MachineIdentificationState state;
  final bool isResolving;
  final VoidCallback onIdentify;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final failure = state is MachineIdentificationFailure
        ? state as MachineIdentificationFailure
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Identificador de máquina', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: identifierController,
          enabled: !isResolving,
          decoration: const InputDecoration(
            hintText: 'Código QR o ID interno',
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onIdentify(),
        ),
        const SizedBox(height: 16),
        if (isResolving) ...[
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 12),
          Text(
            'Resolviendo máquina...',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
        ],
        FilledButton(
          onPressed: isResolving ? null : onIdentify,
          child: const Text('Identificar máquina'),
        ),
        if (failure != null) ...[
          const SizedBox(height: 16),
          Text(
            failure.message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
          if (failure.canRetry) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: isResolving ? null : onRetry,
              child: const Text('Reintentar'),
            ),
          ],
        ],
      ],
    );
  }
}

class _ResolvedView extends StatelessWidget {
  const _ResolvedView({
    required this.theme,
    required this.name,
    required this.identifier,
    required this.machineType,
    required this.status,
    required this.onContinue,
    required this.onIdentifyAnother,
  });

  final ThemeData theme;
  final String name;
  final String identifier;
  final String machineType;
  final String status;
  final VoidCallback onContinue;
  final VoidCallback onIdentifyAnother;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Máquina identificada',
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          name,
          style: theme.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          identifier,
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          '$machineType · $status',
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: onContinue,
          child: const Text('Ver detalle y slots'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: onIdentifyAnother,
          child: const Text('Identificar otra máquina'),
        ),
      ],
    );
  }
}
