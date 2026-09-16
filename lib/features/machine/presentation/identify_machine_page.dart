import 'package:flutter/material.dart';

import '../../../app/bootstrap/app_dependencies.dart';
import '../../../app/router/app_router.dart';
import '../../replenishment/application/visit_start_controller.dart';
import '../../replenishment/application/visit_start_state.dart';

/// Scan/enter machine id → resolve + slots + create visit, then open line entry.
class IdentifyMachinePage extends StatefulWidget {
  const IdentifyMachinePage({
    super.key,
    this.controller,
    this.onSignOut,
  });

  final VisitStartController? controller;
  final VoidCallback? onSignOut;

  @override
  State<IdentifyMachinePage> createState() => _IdentifyMachinePageState();
}

class _IdentifyMachinePageState extends State<IdentifyMachinePage> {
  late final TextEditingController _identifierController;
  var _navigatedForReady = false;

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

  void _goToLinesIfReady(VisitStartController controller) {
    if (controller.state is! VisitStartReady || _navigatedForReady) {
      return;
    }
    _navigatedForReady = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacementNamed(
        AppRouter.replenishmentLineEntryPath,
      );
      controller.resetToIdle();
      _navigatedForReady = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller =
        widget.controller ??
        AppDependenciesScope.of(context).visitStartController;
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.state;
        _goToLinesIfReady(controller);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Identificar máquina'),
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
                VisitStartSessionExpired() => Center(
                  child: Text(
                    'La sesión ha expirado. Vuelve a iniciar sesión.',
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
                VisitStartNoOperator() => Center(
                  child: Text(
                    'No hay un operador cargado. Vuelve a iniciar sesión.',
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
                VisitStartStarting(:final phase) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(phase, textAlign: TextAlign.center),
                    ],
                  ),
                ),
                VisitStartReady(:final machine) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Abriendo reposición en ${machine.name}...',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                _ => _IdentifyForm(
                  theme: theme,
                  identifierController: _identifierController,
                  state: state,
                  isStarting: controller.isStarting,
                  onIdentify: () {
                    _navigatedForReady = false;
                    controller.startFromIdentifier(_identifierController.text);
                  },
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
    required this.isStarting,
    required this.onIdentify,
    required this.onRetry,
  });

  final ThemeData theme;
  final TextEditingController identifierController;
  final VisitStartState state;
  final bool isStarting;
  final VoidCallback onIdentify;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final failure = state is VisitStartFailure
        ? state as VisitStartFailure
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Escanea o ingresa el código de la máquina para iniciar la reposición.',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: identifierController,
          enabled: !isStarting,
          decoration: const InputDecoration(
            labelText: 'Código / QR',
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onIdentify(),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: isStarting ? null : onIdentify,
          child: Text(isStarting ? 'Iniciando...' : 'Identificar e iniciar'),
        ),
        if (failure != null) ...[
          const SizedBox(height: 16),
          Text(
            failure.message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          if (failure.canRetry) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ],
      ],
    );
  }
}
