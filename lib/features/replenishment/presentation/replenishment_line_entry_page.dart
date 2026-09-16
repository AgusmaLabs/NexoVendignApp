import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/bootstrap/app_dependencies.dart';
import '../../machine/domain/machine_slot.dart';
import '../../products/application/product_lookup_controller.dart';
import '../../products/application/product_lookup_state.dart';
import '../../products/domain/product.dart';
import '../../products/domain/unresolved_product.dart';
import '../application/replenishment_add_line_controller.dart';
import '../application/replenishment_add_line_state.dart';
import '../application/replenishment_creation_controller.dart';

/// Single field screen: scan → resolve/search/PENDING → slot + quantity → next.
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
  late final TextEditingController _searchController;
  late final TextEditingController _manualDescriptionController;
  String? _boundProductId;
  String? _boundUnresolvedKey;
  String? _lastSuccessMessage;
  String? _manualValidationMessage;
  var _handlingAdded = false;

  @override
  void initState() {
    super.initState();
    _barcodeController = TextEditingController();
    _quantityController = TextEditingController();
    _searchController = TextEditingController();
    _manualDescriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _quantityController.dispose();
    _searchController.dispose();
    _manualDescriptionController.dispose();
    super.dispose();
  }

  void _bindProductIfNeeded(
    ProductLookupController lookup,
    ReplenishmentAddLineController addLine,
  ) {
    final state = lookup.state;
    if (state is ProductLookupFound) {
      if (_boundProductId == state.product.productId &&
          addLine.product?.productId == state.product.productId) {
        return;
      }
      _boundProductId = state.product.productId;
      _boundUnresolvedKey = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        addLine.beginWithProduct(state.product, barcode: state.barcode);
        _quantityController.clear();
      });
      return;
    }

    if (state is ProductLookupUnresolvedReady) {
      final key =
          '${state.unresolved.barcode}|${state.unresolved.manualDescription}';
      if (_boundUnresolvedKey == key && addLine.unresolved == state.unresolved) {
        return;
      }
      _boundUnresolvedKey = key;
      _boundProductId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        addLine.beginWithUnresolved(state.unresolved);
        _quantityController.clear();
      });
    }
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
      final pending = line?.resolutionStatus
              .toLowerCase()
              .contains('pending') ==
          true;
      if (pending && lookup.lastUnresolved != null) {
        lookup.markPendingLineSubmitted(lookup.lastUnresolved!);
      }
      setState(() {
        _lastSuccessMessage = line == null
            ? 'Línea agregada.'
            : pending
            ? 'Línea pendiente registrada (${line.quantity} u.). '
                'Escanea el siguiente.'
            : 'Línea agregada (${line.quantity} u.). Escanea el siguiente.';
        _boundProductId = null;
        _boundUnresolvedKey = null;
        _manualValidationMessage = null;
      });
      addLine.prepareForNextLine();
      lookup.prepareForNextLine();
      _barcodeController.clear();
      _quantityController.clear();
      _searchController.clear();
      _manualDescriptionController.clear();
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
                      manualValidationMessage: _manualValidationMessage,
                      lookup: lookup,
                      addLine: addLine,
                      barcodeController: _barcodeController,
                      quantityController: _quantityController,
                      searchController: _searchController,
                      manualDescriptionController:
                          _manualDescriptionController,
                      onClearSuccess: () {
                        if (_lastSuccessMessage != null) {
                          setState(() => _lastSuccessMessage = null);
                        }
                      },
                      onManualValidation: (message) {
                        setState(() => _manualValidationMessage = message);
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
    required this.manualValidationMessage,
    required this.lookup,
    required this.addLine,
    required this.barcodeController,
    required this.quantityController,
    required this.searchController,
    required this.manualDescriptionController,
    required this.onClearSuccess,
    required this.onManualValidation,
  });

  final ThemeData theme;
  final String? machineName;
  final String? machineIdentifier;
  final int lineCount;
  final String? successMessage;
  final String? manualValidationMessage;
  final ProductLookupController lookup;
  final ReplenishmentAddLineController addLine;
  final TextEditingController barcodeController;
  final TextEditingController quantityController;
  final TextEditingController searchController;
  final TextEditingController manualDescriptionController;
  final VoidCallback onClearSuccess;
  final ValueChanged<String?> onManualValidation;

  @override
  Widget build(BuildContext context) {
    final lookupState = lookup.state;
    final addState = addLine.state;
    final product = switch (lookupState) {
      ProductLookupFound(:final product) => product,
      _ => addLine.product,
    };
    final unresolved = switch (lookupState) {
      ProductLookupUnresolvedReady(:final unresolved) => unresolved,
      _ => addLine.unresolved,
    };
    final barcode = switch (lookupState) {
      ProductLookupFound(:final barcode) => barcode,
      ProductLookupUnresolvedReady(:final unresolved) => unresolved.barcode,
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
        if (product != null || unresolved != null)
          _LineForm(
            theme: theme,
            product: product,
            unresolved: unresolved,
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
              onManualValidation(null);
              addLine.prepareForNextLine();
              lookup.resetToIdle();
              barcodeController.clear();
              quantityController.clear();
              searchController.clear();
              manualDescriptionController.clear();
            },
          )
        else
          _LookupCascade(
            theme: theme,
            lookup: lookup,
            lookupState: lookupState,
            barcodeController: barcodeController,
            searchController: searchController,
            manualDescriptionController: manualDescriptionController,
            manualValidationMessage: manualValidationMessage,
            onClearSuccess: onClearSuccess,
            onManualValidation: onManualValidation,
          ),
      ],
    );
  }
}

class _LookupCascade extends StatelessWidget {
  const _LookupCascade({
    required this.theme,
    required this.lookup,
    required this.lookupState,
    required this.barcodeController,
    required this.searchController,
    required this.manualDescriptionController,
    required this.manualValidationMessage,
    required this.onClearSuccess,
    required this.onManualValidation,
  });

  final ThemeData theme;
  final ProductLookupController lookup;
  final ProductLookupState lookupState;
  final TextEditingController barcodeController;
  final TextEditingController searchController;
  final TextEditingController manualDescriptionController;
  final String? manualValidationMessage;
  final VoidCallback onClearSuccess;
  final ValueChanged<String?> onManualValidation;

  @override
  Widget build(BuildContext context) {
    final state = lookupState;

    if (state is ProductLookupEnteringManualDescription) {
      return _ManualDescriptionSection(
        theme: theme,
        barcode: state.barcode,
        controller: manualDescriptionController,
        validationMessage: manualValidationMessage,
        onChanged: (value) {
          lookup.updateManualDescriptionDraft(value);
          if (manualValidationMessage != null) {
            onManualValidation(null);
          }
        },
        onConfirm: () {
          onClearSuccess();
          final message = lookup.confirmManualDescription(
            manualDescriptionController.text,
          );
          onManualValidation(message);
        },
        onBack: () {
          onManualValidation(null);
          lookup.retry();
        },
      );
    }

    if (state is ProductLookupSearchingByDescription) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Buscando productos...', style: theme.textTheme.titleMedium),
          const SizedBox(height: 24),
          const Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (state is ProductLookupSearchResults) {
      return _SearchResultsSection(
        theme: theme,
        query: state.query,
        products: state.products,
        onSelect: (product) {
          onClearSuccess();
          lookup.selectSearchResult(product);
        },
        onSearchAgain: () {
          onClearSuccess();
          lookup.searchByDescription(searchController.text);
        },
        onManual: () {
          onClearSuccess();
          onManualValidation(null);
          manualDescriptionController.clear();
          lookup.beginManualDescription();
        },
        searchController: searchController,
      );
    }

    if (state is ProductLookupSearchEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Sin resultados para "${state.query}".',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Puedes buscar de nuevo o registrar el producto como pendiente.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: searchController,
            decoration: const InputDecoration(
              labelText: 'Buscar por descripción',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) {
              onClearSuccess();
              lookup.searchByDescription(searchController.text);
            },
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              onClearSuccess();
              lookup.searchByDescription(searchController.text);
            },
            child: const Text('Buscar de nuevo'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              onClearSuccess();
              onManualValidation(null);
              manualDescriptionController.clear();
              lookup.beginManualDescription();
            },
            child: const Text('Describir producto manualmente'),
          ),
        ],
      );
    }

    final notFound =
        state is ProductLookupNotFound ? state : null;
    final failure = state is ProductLookupFailure ? state : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
            state is ProductLookupScanning
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
            state is ProductLookupLookingUp
                ? 'Buscando...'
                : 'Buscar código',
          ),
        ),
        if (notFound != null) ...[
          const SizedBox(height: 16),
          Text(
            'Producto no encontrado (${notFound.barcode}).',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Reintenta el escaneo o busca por descripción en el catálogo.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: searchController,
            decoration: const InputDecoration(
              labelText: 'Buscar por descripción',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) {
              onClearSuccess();
              lookup.searchByDescription(searchController.text);
            },
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: lookup.retry,
            child: const Text('Reintentar escaneo'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              onClearSuccess();
              lookup.searchByDescription(searchController.text);
            },
            child: const Text('Buscar en catálogo'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              onClearSuccess();
              onManualValidation(null);
              manualDescriptionController.clear();
              lookup.beginManualDescription();
            },
            child: const Text('Describir producto manualmente'),
          ),
        ],
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
            TextButton(
              onPressed: lookup.retry,
              child: const Text('Reintentar'),
            ),
          ],
        ],
        if (state is ProductLookupNoReplenishment) ...[
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
      ],
    );
  }
}

class _SearchResultsSection extends StatelessWidget {
  const _SearchResultsSection({
    required this.theme,
    required this.query,
    required this.products,
    required this.onSelect,
    required this.onSearchAgain,
    required this.onManual,
    required this.searchController,
  });

  final ThemeData theme;
  final String query;
  final List<Product> products;
  final ValueChanged<Product> onSelect;
  final VoidCallback onSearchAgain;
  final VoidCallback onManual;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Resultados para "$query"',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        for (final product in products)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(product.description),
            subtitle: Text('${product.barcode} · ${product.unit}'),
            onTap: () => onSelect(product),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: searchController,
          decoration: const InputDecoration(
            labelText: 'Buscar de nuevo',
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => onSearchAgain(),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: onSearchAgain,
          child: const Text('Buscar de nuevo'),
        ),
        TextButton(
          onPressed: onManual,
          child: const Text('Ninguno coincide — describir manualmente'),
        ),
      ],
    );
  }
}

class _ManualDescriptionSection extends StatelessWidget {
  const _ManualDescriptionSection({
    required this.theme,
    required this.barcode,
    required this.controller,
    required this.validationMessage,
    required this.onChanged,
    required this.onConfirm,
    required this.onBack,
  });

  final ThemeData theme;
  final String? barcode;
  final TextEditingController controller;
  final String? validationMessage;
  final ValueChanged<String> onChanged;
  final VoidCallback onConfirm;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Producto pendiente de resolución',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Describe el producto. Quedará pendiente hasta que se resuelva '
          'en catálogo.',
          style: theme.textTheme.bodyMedium,
        ),
        if (barcode != null && barcode!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Código escaneado: $barcode', style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: controller,
          onChanged: onChanged,
          maxLength: 500,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Descripción del producto',
            border: OutlineInputBorder(),
          ),
        ),
        if (validationMessage != null) ...[
          Text(
            validationMessage!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 8),
        ],
        FilledButton(
          onPressed: onConfirm,
          child: const Text('Continuar'),
        ),
        TextButton(
          onPressed: onBack,
          child: const Text('Volver a escanear'),
        ),
      ],
    );
  }
}

class _LineForm extends StatelessWidget {
  const _LineForm({
    required this.theme,
    required this.product,
    required this.unresolved,
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
  final Product? product;
  final UnresolvedProduct? unresolved;
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
    final pending = unresolved != null && product == null;
    final title = product?.description ?? unresolved!.manualDescription;
    final subtitle = pending
        ? 'Pendiente de resolución en catálogo'
        : 'Unidad: ${product!.unit}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: theme.textTheme.titleLarge),
        if (barcode != null && barcode!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Código: $barcode', style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: pending ? theme.colorScheme.tertiary : null,
          ),
        ),
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
          child: Text(
            busy
                ? 'Agregando...'
                : pending
                ? 'Registrar línea pendiente'
                : 'Agregar línea',
          ),
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
