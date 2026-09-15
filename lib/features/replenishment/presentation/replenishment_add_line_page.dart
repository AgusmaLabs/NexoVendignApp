import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/bootstrap/app_dependencies.dart';
import '../../../app/router/app_router.dart';
import '../../machine/domain/machine_slot.dart';
import '../../products/domain/product.dart';
import '../application/replenishment_add_line_controller.dart';
import '../application/replenishment_add_line_state.dart';
import '../domain/replenishment_line.dart';

/// Quantity + slot capture → add replenishment line.
class ReplenishmentAddLinePage extends StatefulWidget {
  const ReplenishmentAddLinePage({
    required this.product,
    super.key,
    this.barcode,
    this.controller,
    this.onSignOut,
  });

  final Product product;
  final String? barcode;
  final ReplenishmentAddLineController? controller;
  final VoidCallback? onSignOut;

  @override
  State<ReplenishmentAddLinePage> createState() =>
      _ReplenishmentAddLinePageState();
}

class _ReplenishmentAddLinePageState extends State<ReplenishmentAddLinePage> {
  late final TextEditingController _quantityController;
  var _prepared = false;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resolvedController = widget.controller;
    final ReplenishmentAddLineController effectiveController;
    if (resolvedController != null) {
      effectiveController = resolvedController;
    } else {
      effectiveController =
          AppDependenciesScope.of(context).replenishmentAddLineController;
    }

    if (!_prepared) {
      _prepared = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        effectiveController.beginWithProduct(
          widget.product,
          barcode: widget.barcode,
        );
      });
    }

    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: effectiveController,
      builder: (context, _) {
        final state = effectiveController.state;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Agregar línea'),
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
                ReplenishmentAddLineAdded(:final line, :final replenishment) =>
                  _AddedView(
                    theme: theme,
                    line: line,
                    lineCount: replenishment.lines.length,
                    onAddAnother: () {
                      Navigator.of(context).pushReplacementNamed(
                        AppRouter.productLookupPath,
                      );
                    },
                    onBackToReplenishment: () {
                      Navigator.of(context).popUntil(
                        (route) =>
                            route.settings.name ==
                                AppRouter.replenishmentStartPath ||
                            route.isFirst,
                      );
                    },
                  ),
                ReplenishmentAddLineSessionExpired() => Center(
                  child: Text(
                    'La sesión ha expirado. Vuelve a iniciar sesión.',
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
                ReplenishmentAddLineAdding() => const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Agregando línea...'),
                    ],
                  ),
                ),
                ReplenishmentAddLineFailure(:final message, :final canRetry) =>
                  _MessageView(
                    theme: theme,
                    message: message,
                    error: true,
                    actionLabel: canRetry ? 'Reintentar' : null,
                    onAction: canRetry ? effectiveController.retry : null,
                    secondaryLabel: 'Volver',
                    onSecondary: effectiveController.resetToIdle,
                  ),
                ReplenishmentAddLineValidationFailure(:final message) =>
                  _FormView(
                    theme: theme,
                    product: widget.product,
                    barcode: widget.barcode,
                    slots: effectiveController.availableSlots,
                    selectedSlotId: effectiveController.selectedSlotId,
                    quantityController: _quantityController,
                    validationMessage: message,
                    busy: false,
                    onSelectSlot: effectiveController.selectSlot,
                    onSubmit: () {
                      final parsed = int.tryParse(
                        _quantityController.text.trim(),
                      );
                      effectiveController.setQuantity(parsed);
                      effectiveController.submit();
                    },
                  ),
                _ => _FormView(
                  theme: theme,
                  product: widget.product,
                  barcode: widget.barcode,
                  slots: effectiveController.availableSlots,
                  selectedSlotId: effectiveController.selectedSlotId,
                  quantityController: _quantityController,
                  busy: false,
                  onSelectSlot: effectiveController.selectSlot,
                  onSubmit: () {
                    final parsed = int.tryParse(
                      _quantityController.text.trim(),
                    );
                    effectiveController.setQuantity(parsed);
                    effectiveController.submit();
                  },
                ),
              },
            ),
          ),
        );
      },
    );
  }
}

class _FormView extends StatelessWidget {
  const _FormView({
    required this.theme,
    required this.product,
    required this.slots,
    required this.quantityController,
    required this.busy,
    required this.onSelectSlot,
    required this.onSubmit,
    this.barcode,
    this.selectedSlotId,
    this.validationMessage,
  });

  final ThemeData theme;
  final Product product;
  final String? barcode;
  final List<MachineSlot> slots;
  final String? selectedSlotId;
  final TextEditingController quantityController;
  final String? validationMessage;
  final bool busy;
  final ValueChanged<String> onSelectSlot;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Text('Producto', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(product.description, style: theme.textTheme.titleLarge),
        if (barcode != null) ...[
          const SizedBox(height: 4),
          Text('Código: $barcode', style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: 24),
        Text('Cantidad', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: quantityController,
          enabled: !busy,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Ej. 12',
          ),
        ),
        const SizedBox(height: 24),
        Text('Slot', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (slots.isEmpty)
          Text(
            'No hay slots configurados para esta máquina.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          )
        else
          ...slots.map((slot) {
            final selected = slot.slotId == selectedSlotId;
            return ListTile(
              title: Text(slot.identifier),
              subtitle: Text(
                'Capacidad: ${slot.capacity} · ${slot.status}',
              ),
              selected: selected,
              trailing: selected
                  ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                  : const Icon(Icons.circle_outlined),
              onTap: busy ? null : () => onSelectSlot(slot.slotId),
            );
          }),
        if (validationMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            validationMessage!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: busy || slots.isEmpty ? null : onSubmit,
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}

class _AddedView extends StatelessWidget {
  const _AddedView({
    required this.theme,
    required this.line,
    required this.lineCount,
    required this.onAddAnother,
    required this.onBackToReplenishment,
  });

  final ThemeData theme;
  final ReplenishmentLine line;
  final int lineCount;
  final VoidCallback onAddAnother;
  final VoidCallback onBackToReplenishment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Línea agregada',
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(line.productDescriptionSnapshot, style: theme.textTheme.titleLarge),
        Text('Cantidad: ${line.quantity}'),
        Text('Slot: ${line.slotId}'),
        Text('Líneas en reposición: $lineCount'),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: onAddAnother,
          child: const Text('Agregar otro producto'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: onBackToReplenishment,
          child: const Text('Volver a reposición'),
        ),
      ],
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.theme,
    required this.message,
    this.error = false,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  final ThemeData theme;
  final String message;
  final bool error;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

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
          if (secondaryLabel != null && onSecondary != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
          ],
        ],
      ),
    );
  }
}
