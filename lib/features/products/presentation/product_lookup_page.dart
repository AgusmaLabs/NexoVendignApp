import 'package:flutter/material.dart';

import '../../../app/bootstrap/app_dependencies.dart';
import '../../../app/router/app_router.dart';
import '../../replenishment/application/replenishment_add_line_state.dart';
import '../application/product_lookup_controller.dart';
import '../application/product_lookup_state.dart';
import '../domain/product.dart';

/// Barcode scan / manual entry → product lookup (no replenishment line yet).
class ProductLookupPage extends StatefulWidget {
  const ProductLookupPage({
    super.key,
    this.controller,
    this.onSignOut,
    this.onContinue,
  });

  final ProductLookupController? controller;
  final VoidCallback? onSignOut;
  final ValueChanged<Product>? onContinue;

  @override
  State<ProductLookupPage> createState() => _ProductLookupPageState();
}

class _ProductLookupPageState extends State<ProductLookupPage> {
  late final TextEditingController _barcodeController;

  @override
  void initState() {
    super.initState();
    _barcodeController = TextEditingController();
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resolvedController = widget.controller;
    final ProductLookupController effectiveController;
    if (resolvedController != null) {
      effectiveController = resolvedController;
    } else {
      effectiveController =
          AppDependenciesScope.of(context).productLookupController;
    }

    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: effectiveController,
      builder: (context, _) {
        final state = effectiveController.state;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Agregar producto'),
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
                ProductLookupFound(:final barcode, :final product) =>
                  _FoundView(
                    theme: theme,
                    barcode: barcode,
                    product: product,
                    onContinue: () {
                      if (widget.onContinue != null) {
                        widget.onContinue!(product);
                        return;
                      }
                      Navigator.of(context).pushNamed(
                        AppRouter.replenishmentAddLinePath,
                        arguments: AddLineArgs(
                          product: product,
                          barcode: barcode,
                        ),
                      );
                    },
                    onScanAgain: effectiveController.resetToIdle,
                  ),
                ProductLookupNotFound(:final barcode) => _NotFoundView(
                  theme: theme,
                  barcode: barcode,
                  onScanAgain: () {
                    _barcodeController.clear();
                    effectiveController.resetToIdle();
                  },
                  onManual: () {
                    _barcodeController.text = barcode;
                    effectiveController.resetToIdle();
                  },
                ),
                ProductLookupSessionExpired() => Center(
                  child: Text(
                    'La sesión ha expirado. Vuelve a iniciar sesión.',
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
                ProductLookupNoReplenishment() => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Inicia una reposición antes de escanear productos.',
                        style: theme.textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          Navigator.of(context).pushNamed(
                            AppRouter.replenishmentStartPath,
                          );
                        },
                        child: const Text('Ir a reposición'),
                      ),
                    ],
                  ),
                ),
                ProductLookupFailure(:final message, :final canRetry) =>
                  Center(
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
                        const SizedBox(height: 16),
                        if (canRetry)
                          FilledButton(
                            onPressed: effectiveController.retry,
                            child: const Text('Reintentar'),
                          ),
                        TextButton(
                          onPressed: effectiveController.resetToIdle,
                          child: const Text('Volver'),
                        ),
                      ],
                    ),
                  ),
                ProductLookupLookingUp(:final barcode) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Buscando producto...',
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(barcode, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                ProductLookupScanning() => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Abriendo escáner...',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                _ => _IdleView(
                  theme: theme,
                  barcodeController: _barcodeController,
                  busy: effectiveController.isBusy,
                  onScan: effectiveController.scanAndLookup,
                  onLookup: () =>
                      effectiveController.lookup(_barcodeController.text),
                ),
              },
            ),
          ),
        );
      },
    );
  }
}

class _IdleView extends StatelessWidget {
  const _IdleView({
    required this.theme,
    required this.barcodeController,
    required this.busy,
    required this.onScan,
    required this.onLookup,
  });

  final ThemeData theme;
  final TextEditingController barcodeController;
  final bool busy;
  final VoidCallback onScan;
  final VoidCallback onLookup;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Agregar producto',
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: busy ? null : onScan,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Escanear'),
        ),
        const SizedBox(height: 16),
        Text('o', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        TextField(
          controller: barcodeController,
          enabled: !busy,
          decoration: const InputDecoration(
            labelText: 'Código de barras',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.visiblePassword,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => onLookup(),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: busy ? null : onLookup,
          child: const Text('Buscar'),
        ),
      ],
    );
  }
}

class _FoundView extends StatelessWidget {
  const _FoundView({
    required this.theme,
    required this.barcode,
    required this.product,
    required this.onContinue,
    required this.onScanAgain,
  });

  final ThemeData theme;
  final String barcode;
  final Product product;
  final VoidCallback onContinue;
  final VoidCallback onScanAgain;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Producto encontrado',
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Text(product.description, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text('Código: $barcode', style: theme.textTheme.bodyLarge),
        Text(
          '${product.unit} · ${product.status}',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: onContinue,
          child: const Text('Continuar'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: onScanAgain,
          child: const Text('Escanear otro'),
        ),
      ],
    );
  }
}

class _NotFoundView extends StatelessWidget {
  const _NotFoundView({
    required this.theme,
    required this.barcode,
    required this.onScanAgain,
    required this.onManual,
  });

  final ThemeData theme;
  final String barcode;
  final VoidCallback onScanAgain;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Producto no encontrado',
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          barcode,
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: onScanAgain,
          child: const Text('Escanear nuevamente'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: onManual,
          child: const Text('Ingresar código'),
        ),
      ],
    );
  }
}
