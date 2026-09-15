import 'package:flutter/material.dart';

import '../../../app/bootstrap/app_dependencies.dart';
import '../application/machine_detail_controller.dart';
import '../application/machine_detail_state.dart';
import '../domain/machine_detail.dart';
import '../domain/machine_slot.dart';

/// Shows machine detail and physical slot configuration.
class MachineDetailPage extends StatefulWidget {
  const MachineDetailPage({
    required this.machineId,
    super.key,
    this.controller,
    this.onSignOut,
    this.autoLoad = true,
  });

  final String machineId;
  final MachineDetailController? controller;
  final VoidCallback? onSignOut;
  final bool autoLoad;

  @override
  State<MachineDetailPage> createState() => _MachineDetailPageState();
}

class _MachineDetailPageState extends State<MachineDetailPage> {
  @override
  void initState() {
    super.initState();
    if (widget.autoLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final controller =
            widget.controller ??
            AppDependenciesScope.of(context).machineDetailController;
        if (controller.state is MachineDetailInitial) {
          controller.load(widget.machineId);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller =
        widget.controller ??
        AppDependenciesScope.of(context).machineDetailController;
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.state;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Detalle de máquina'),
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
              padding: const EdgeInsets.all(16),
              child: switch (state) {
                MachineDetailLoading() || MachineDetailInitial() => const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Cargando configuración de la máquina...'),
                    ],
                  ),
                ),
                MachineDetailLoaded(
                  :final detail,
                  :final slots,
                  :final selectedSlotId,
                ) =>
                  _LoadedView(
                    theme: theme,
                    detail: detail,
                    slots: slots,
                    selectedSlotId: selectedSlotId,
                    onSelectSlot: controller.selectSlot,
                    onStartReplenishment: () {
                      Navigator.of(context).pushNamed('/replenishments/start');
                    },
                  ),
                MachineDetailFailure(:final message, :final canRetry) => Center(
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
                      if (canRetry) ...[
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: controller.retry,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ],
                  ),
                ),
                MachineDetailSessionExpired() => Center(
                  child: Text(
                    'La sesión ha expirado. Vuelve a iniciar sesión.',
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
              },
            ),
          ),
        );
      },
    );
  }
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({
    required this.theme,
    required this.detail,
    required this.slots,
    required this.selectedSlotId,
    required this.onSelectSlot,
    required this.onStartReplenishment,
  });

  final ThemeData theme;
  final MachineDetail detail;
  final List<MachineSlot> slots;
  final String? selectedSlotId;
  final ValueChanged<String> onSelectSlot;
  final VoidCallback onStartReplenishment;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Text('Máquina', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(detail.name, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(detail.identifier, style: theme.textTheme.bodyLarge),
        Text(
          '${detail.machineType} · ${detail.status}',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        Text('Configuración física', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (slots.isEmpty)
          Text(
            'No hay slots configurados',
            style: theme.textTheme.bodyMedium,
          )
        else
          ...slots.map((slot) {
            final selected = slot.slotId == selectedSlotId;
            return Card(
              color: selected
                  ? theme.colorScheme.primaryContainer
                  : theme.cardColor,
              child: ListTile(
                title: Text(slot.identifier),
                subtitle: Text(_slotSubtitle(slot)),
                selected: selected,
                onTap: () => onSelectSlot(slot.slotId),
              ),
            );
          }),
        if (selectedSlotId != null) ...[
          const SizedBox(height: 16),
          Text(
            'Slot seleccionado (listo para reposición).',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: onStartReplenishment,
          child: const Text('Iniciar reposición'),
        ),
      ],
    );
  }

  String _slotSubtitle(MachineSlot slot) {
    final parts = <String>[
      'Capacidad: ${slot.capacity}',
      'Estado: ${slot.status}',
    ];
    final preferred = slot.preferredProductId;
    if (preferred != null && preferred.isNotEmpty) {
      parts.add('Producto preferido: $preferred');
    } else {
      parts.add('Sin producto preferido');
    }
    final price = slot.sellingPrice;
    if (price != null && price.isNotEmpty) {
      parts.add('Precio: $price');
    }
    final qty = slot.currentQuantity;
    if (qty != null) {
      parts.add('Cantidad: $qty');
    }
    return parts.join(' · ');
  }
}
