import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/bootstrap/app_dependencies.dart';
import '../../machine/domain/machine_slot.dart';
import '../../products/application/product_lookup_controller.dart';
import '../../products/application/product_lookup_state.dart';
import '../../products/domain/product.dart';
import '../application/replenishment_add_line_controller.dart';
import '../application/replenishment_add_line_state.dart';
import '../application/replenishment_creation_controller.dart';

/// Single field screen: scan barcode → product → slot + quantity → next line.
class ReplenishmentLineEntryPage extends StatefulWidget {
  const ReplenishmentLineEntryPage({
    super.key,
    this.productLookupController,
    this.addLineController,
    this.creationController,
    this.onSignOut,
  });

  final ProductLookupController? productLookupController;
  final ReplenishmentAddLineController? addLineController;
  final ReplenishmentCreationController? creationController;
  final VoidCallback? onSignOut;

  @override
  State<ReplenishmentLineEntryPage> createState() =>
      _ReplenishmentLineEntryPageState();
}

class _ReplenishmentLineEntryPageState extends State<ReplenishmentLineEntryPage> {
  late final TextEditingController _barcodeController;
  late final TextEditingController _quantityController;
  String? _boundProductId;
  String? _lastSuccessMessage;
  var _handlingAdded = false;

  @override
  void initState() {
    super.initState();
    _barcodeController = TextEditingController();
    _quantityController = TextEditingController();
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _bindProductIfNeeded(
    ProductLookupController lookup,
    ReplenishmentAddLineController addLine,
  ) {
    final state = lookup.state;
    if (state is! ProductLookupFound) {
      return;
    }
    if (_boundProductId == state.product.productId &&
        addLine.product?.productId == state.product.productId) {
      return;
    }
    _boundProductId = state.product.productId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      addLine.beginWithProduct(state.product, barcode: state.barcode);
      _quantityController.clear();
    });
  }

  void _scheduleAfterLineAdded(
    ProductLookupController lookup,
    ReplenishmentAddLineController addLine,
  ) {
    if (_handlingAdded || addLine.state is! ReplenishmentAddLineAdded) {
      return;
    }
    _handlingAdded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final line = addLine.lastAddedLine;
      setState(() {
        _lastSuccessMessage = line == null
            ? 'Línea agregada.'
            : 'Línea agregada (${line.quantity} u.). Escanea el siguiente.';
        _boundProductId = null;
      });
      addLine.prepareForNextLine();
      lookup.resetToIdle();
      _barcodeController.clear();
      _quantityController.clear();
      _handlingAdded = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final deps = AppDependenciesScope.of(context);
    final lookup =
        widget.productLookupController ?? deps.productLookupController;
    final addLine =
        widget.addLineController ?? deps.replenishmentAddLineController;
    final creation =
        widget.creationController ?? deps.replenishmentCreationController;
    final theme = Theme.of(context);
    final machine = deps.machineIdentificationController.currentMachine;
    final replenishment = creation.currentReplenishment;

    return ListenableBuilder(
      listenable: Listenable.merge([lookup, addLine, creation]),
      builder: (context, _) {
        _bindProductIfNeeded(lookup, addLine);
        _scheduleAfterLineAdded(lookup, addLine);

        final lookupState = lookup.state;
        final addState = addLine.state;
        final sessionExpired =
            lookupState is ProductLookupSessionExpired ||
            addState is ReplenishmentAddLineSessionExpired;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Reposición'),
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
              child: replenishment == null
                  ? Center(
                      child: Text(
                        'No hay una reposición activa. Identifica una máquina.',
                        style: theme.textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                    )
                  : sessionExpired
                  ? Center(
                      child: Text(
                        'La sesión ha expirado. Vuelve a iniciar sesión.',
                        style: theme.textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                    )
                  : addState is ReplenishmentAddLineAdding
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Agregando línea...'),
                        ],
                      ),
                    )
                  : _LineEntryBody(
                      theme: theme,
                      machineName: machine?.name,
                      machineIdentifier: machine?.identifier,
                      lineCount: replenishment.lines.length,
                      successMessage: _lastSuccessMessage,
                      lookup: lookup,
                      addLine: addLine,
                      barcodeController: _barcodeController,
                      quantityController: _quantityController,
                      onClearSuccess: () {
                        if (_lastSuccessMessage != null) {
                          setState(() => _lastSuccessMessage = null);
                        }
                      },
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _LineEntryBody extends StatelessWidget {
  const _LineEntryBody({
    required this.theme,
    required this.machineName,
    required this.machineIdentifier,
    required this.lineCount,
    required this.successMessage,
    required this.lookup,
    required this.addLine,
    required this.barcodeController,
    required this.quantityController,
    required this.onClearSuccess,
  });

  final ThemeData theme;
  final String? machineName;
  final String? machineIdentifier;
  final int lineCount;
  final String? successMessage;
  final ProductLookupController lookup;
  final ReplenishmentAddLineController addLine;
  final TextEditingController barcodeController;
  final TextEditingController quantityController;
  final VoidCallback onClearSuccess;

  @override
  Widget build(BuildContext context) {
    final lookupState = lookup.state;
    final addState = addLine.state;
    final product = switch (lookupState) {
      ProductLookupFound(:final product) => product,
      _ => addLine.product,
    };
    final barcode = switch (lookupState) {
      ProductLookupFound(:final barcode) => barcode,
      _ => addLine.barcode,
    };

    return ListView(
      children: [
        if (machineName != null || machineIdentifier != null) ...[
          Text(
            machineName ?? 'Máquina',
            style: theme.textTheme.titleMedium,
          ),
          if (machineIdentifier != null)
            Text(machineIdentifier!, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 4),
        ],
        Text(
          lineCount == 0
              ? 'Sin líneas aún'
              : 'Líneas en esta visita: $lineCount',
          style: theme.textTheme.bodySmall,
        ),
        if (successMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            successMessage!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
        const SizedBox(height: 20),
        if (product == null) ...[
          Text('Escanear producto', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: barcodeController,
            enabled: !lookup.isBusy,
            decoration: const InputDecoration(
              labelText: 'Código de barras',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              onClearSuccess();
              lookup.lookup(barcodeController.text);
            },
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: lookup.isBusy
                ? null
                : () {
                    onClearSuccess();
                    lookup.scanAndLookup();
                  },
            child: Text(
              lookupState is ProductLookupScanning
                  ? 'Abriendo cámara...'
                  : 'Escanear código',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: lookup.isBusy
                ? null
                : () {
                    onClearSuccess();
                    lookup.lookup(barcodeController.text);
                  },
            child: Text(
              lookupState is ProductLookupLookingUp
                  ? 'Buscando...'
                  : 'Buscar código',
            ),
          ),
          if (lookupState is ProductLookupNotFound) ...[
            const SizedBox(height: 16),
            Text(
              'Producto no encontrado (${lookupState.barcode}).',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          if (lookupState is ProductLookupFailure) ...[
            const SizedBox(height: 16),
            Text(
              lookupState.message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            if (lookupState.canRetry) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: lookup.retry,
                child: const Text('Reintentar'),
              ),
            ],
          ],
          if (lookupState is ProductLookupNoReplenishment) ...[
            const SizedBox(height: 16),
            Text(
              'Inicia una reposición antes de escanear productos.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          if (lookup.isBusy) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],
        ] else ...[
          _ProductAndLineForm(
            theme: theme,
            product: product,
            barcode: barcode,
            slots: addLine.availableSlots,
            selectedSlotId: addLine.selectedSlotId,
            quantityController: quantityController,
            validationMessage: addState is ReplenishmentAddLineValidationFailure
                ? addState.message
                : null,
            errorMessage: addState is ReplenishmentAddLineFailure
                ? addState.message
                : null,
            canRetryError:
                addState is ReplenishmentAddLineFailure && addState.canRetry,
            busy: addLine.isAdding,
            onSelectSlot: (id) {
              onClearSuccess();
              addLine.selectSlot(id);
            },
            onSubmit: () {
              onClearSuccess();
              final parsed = int.tryParse(quantityController.text.trim());
              addLine.setQuantity(parsed);
              addLine.submit();
            },
            onRetry: addLine.retry,
            onScanAnother: () {
              onClearSuccess();
              addLine.prepareForNextLine();
              lookup.resetToIdle();
              barcodeController.clear();
              quantityController.clear();
            },
          ),
        ],
      ],
    );
  }
}

class _ProductAndLineForm extends StatelessWidget {
  const _ProductAndLineForm({
    required this.theme,
    required this.product,
    required this.barcode,
    required this.slots,
    required this.selectedSlotId,
    required this.quantityController,
    required this.validationMessage,
    required this.errorMessage,
    required this.canRetryError,
    required this.busy,
    required this.onSelectSlot,
    required this.onSubmit,
    required this.onRetry,
    required this.onScanAnother,
  });

  final ThemeData theme;
  final Product product;
  final String? barcode;
  final List<MachineSlot> slots;
  final String? selectedSlotId;
  final TextEditingController quantityController;
  final String? validationMessage;
  final String? errorMessage;
  final bool canRetryError;
  final bool busy;
  final ValueChanged<String> onSelectSlot;
  final VoidCallback onSubmit;
  final VoidCallback onRetry;
  final VoidCallback onScanAnother;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(product.description, style: theme.textTheme.titleLarge),
        if (barcode != null && barcode!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Código: $barcode', style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: 4),
        Text('Unidad: ${product.unit}', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 20),
        Text('Slot', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        if (slots.isEmpty)
          Text(
            'Esta máquina no tiene slots configurados.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final slot in slots)
                ChoiceChip(
                  label: Text('Slot ${slot.slotNumber}'),
                  selected: selectedSlotId == slot.slotId,
                  onSelected: busy
                      ? null
                      : (selected) {
                          if (selected) {
                            onSelectSlot(slot.slotId);
                          }
                        },
                ),
            ],
          ),
        const SizedBox(height: 16),
        TextField(
          controller: quantityController,
          enabled: !busy,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Cantidad',
            border: OutlineInputBorder(),
          ),
        ),
        if (validationMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            validationMessage!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        if (errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            errorMessage!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          if (canRetryError) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: busy || slots.isEmpty ? null : onSubmit,
          child: Text(busy ? 'Agregando...' : 'Agregar línea'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: busy ? null : onScanAnother,
          child: const Text('Escanear otro producto'),
        ),
      ],
    );
  }
}
