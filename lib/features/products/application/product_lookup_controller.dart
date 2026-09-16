import 'package:flutter/foundation.dart';

import '../../../core/authentication/session_service.dart';
import '../../../core/device/barcode_scanner.dart';
import '../../../core/logging/app_logger.dart';
import '../../replenishment/application/replenishment_creation_controller.dart';
import '../domain/barcode_input.dart';
import '../domain/product.dart';
import '../domain/product_exception.dart';
import '../domain/product_lookup_service.dart';
import '../domain/unresolved_product.dart';
import 'product_lookup_state.dart';

/// Scans/enters a barcode and looks up the product in NexoVending.
///
/// Cascade after barcode 404: retry → search by description → PENDING line.
final class ProductLookupController extends ChangeNotifier {
  ProductLookupController({
    required this.productLookupService,
    required this.barcodeScanner,
    required this.replenishmentCreationController,
    required this.sessionService,
    required this.logger,
    this.onSessionExpired,
  });

  final ProductLookupService productLookupService;
  final BarcodeScanner barcodeScanner;
  final ReplenishmentCreationController replenishmentCreationController;
  final SessionService sessionService;
  final AppLogger logger;
  final Future<void> Function()? onSessionExpired;

  ProductLookupState _state = const ProductLookupIdle();
  Product? _lastFoundProduct;
  UnresolvedProduct? _lastUnresolved;
  String? _cascadeBarcode;

  ProductLookupState get state => _state;

  Product? get lastFoundProduct => _lastFoundProduct;

  UnresolvedProduct? get lastUnresolved => _lastUnresolved;

  bool get isBusy =>
      _state is ProductLookupScanning ||
      _state is ProductLookupLookingUp ||
      _state is ProductLookupSearchingByDescription;

  Future<void> scanAndLookup() async {
    if (isBusy) {
      return;
    }
    if (replenishmentCreationController.currentReplenishment == null) {
      _setState(const ProductLookupNoReplenishment());
      return;
    }

    _setState(const ProductLookupScanning());
    logger.info('product_scan_started');

    try {
      final raw = await barcodeScanner.scan();
      if (raw == null) {
        _setState(const ProductLookupIdle());
        return;
      }
      await lookup(raw);
    } on UnsupportedError catch (error) {
      logger.error('product_scan_unavailable', error: error);
      _setState(
        const ProductLookupFailure(
          'El escáner no está disponible. Ingresa el código manualmente.',
          canRetry: false,
        ),
      );
    } catch (error, stackTrace) {
      logger.error(
        'product_scan_failed',
        error: error,
        stackTrace: stackTrace,
      );
      _setState(
        const ProductLookupFailure(
          'No fue posible abrir el escáner.',
        ),
      );
    }
  }

  Future<void> lookup(String barcode) async {
    if (_state is ProductLookupLookingUp) {
      return;
    }
    if (replenishmentCreationController.currentReplenishment == null) {
      _setState(const ProductLookupNoReplenishment());
      return;
    }

    final normalized = BarcodeInput.normalize(barcode);
    if (!BarcodeInput.isValidFormat(normalized)) {
      _setState(
        ProductLookupFailure(
          'El código de barras no es válido.',
          canRetry: false,
          barcode: normalized.isEmpty ? null : normalized,
        ),
      );
      return;
    }

    _cascadeBarcode = normalized;
    _lastUnresolved = null;
    _setState(ProductLookupLookingUp(normalized));
    logger.info('product_lookup_ui_started');

    try {
      final product = await productLookupService.lookupByBarcode(normalized);
      _lastFoundProduct = product;
      _setState(ProductLookupFound(barcode: normalized, product: product));
    } on ProductNotFound catch (error) {
      _setState(ProductLookupNotFound(error.barcode ?? normalized));
    } on ProductSessionExpired {
      await sessionService.clearSession();
      _setState(const ProductLookupSessionExpired());
      await onSessionExpired?.call();
    } on ProductException catch (error) {
      logger.error(
        'product_lookup_ui_failed',
        error: error,
        context: {'type': error.runtimeType.toString()},
      );
      _setState(
        ProductLookupFailure(error.message, barcode: normalized),
      );
    } catch (error, stackTrace) {
      logger.error(
        'product_lookup_ui_failed',
        error: error,
        stackTrace: stackTrace,
      );
      _setState(
        ProductLookupFailure(
          'No fue posible consultar el producto en este momento.',
          barcode: normalized,
        ),
      );
    }
  }

  Future<void> retry() async {
    final current = _state;
    final barcode = switch (current) {
      ProductLookupNotFound(:final barcode) => barcode,
      ProductLookupFailure(:final barcode) => barcode,
      ProductLookupLookingUp(:final barcode) => barcode,
      ProductLookupSearchingByDescription(:final barcode) => barcode,
      ProductLookupSearchResults(:final barcode) => barcode,
      ProductLookupSearchEmpty(:final barcode) => barcode,
      ProductLookupEnteringManualDescription(:final barcode) => barcode,
      _ => _cascadeBarcode,
    };
    if (barcode == null || barcode.isEmpty) {
      _setState(const ProductLookupIdle());
      return;
    }
    await lookup(barcode);
  }

  /// Search catalog by free text after barcode 404 / empty search.
  Future<void> searchByDescription(String query) async {
    if (_state is ProductLookupSearchingByDescription) {
      return;
    }
    if (replenishmentCreationController.currentReplenishment == null) {
      _setState(const ProductLookupNoReplenishment());
      return;
    }

    final trimmed = query.trim();
    if (trimmed.length < 2) {
      _setState(
        ProductLookupFailure(
          const ProductSearchQueryInvalid().message,
          canRetry: false,
          barcode: _cascadeBarcode,
        ),
      );
      return;
    }

    final barcode = _cascadeBarcodeFromState() ?? _cascadeBarcode;
    _setState(
      ProductLookupSearchingByDescription(query: trimmed, barcode: barcode),
    );
    logger.info('product_search_ui_started');

    try {
      final products = await productLookupService.searchByText(trimmed);
      if (products.isEmpty) {
        _setState(
          ProductLookupSearchEmpty(query: trimmed, barcode: barcode),
        );
        return;
      }
      _setState(
        ProductLookupSearchResults(
          query: trimmed,
          products: List<Product>.unmodifiable(products),
          barcode: barcode,
        ),
      );
    } on ProductSessionExpired {
      await sessionService.clearSession();
      _setState(const ProductLookupSessionExpired());
      await onSessionExpired?.call();
    } on ProductException catch (error) {
      logger.error(
        'product_search_ui_failed',
        error: error,
        context: {'type': error.runtimeType.toString()},
      );
      _setState(
        ProductLookupFailure(error.message, barcode: barcode),
      );
    } catch (error, stackTrace) {
      logger.error(
        'product_search_ui_failed',
        error: error,
        stackTrace: stackTrace,
      );
      _setState(
        ProductLookupFailure(
          'No fue posible buscar productos en este momento.',
          barcode: barcode,
        ),
      );
    }
  }

  void selectSearchResult(Product product) {
    final barcode = product.barcode.isNotEmpty
        ? product.barcode
        : (_cascadeBarcode ?? '');
    _lastFoundProduct = product;
    _lastUnresolved = null;
    _setState(ProductLookupFound(barcode: barcode, product: product));
  }

  void beginManualDescription() {
    final barcode = _cascadeBarcodeFromState() ?? _cascadeBarcode;
    _setState(
      ProductLookupEnteringManualDescription(barcode: barcode),
    );
  }

  void updateManualDescriptionDraft(String draft) {
    final current = _state;
    if (current is! ProductLookupEnteringManualDescription) {
      return;
    }
    _setState(
      ProductLookupEnteringManualDescription(
        barcode: current.barcode,
        draftDescription: draft,
      ),
    );
  }

  /// Validates and stores [UnresolvedProduct] for PENDING add-line.
  ///
  /// Returns a validation message when invalid; `null` when ready.
  String? confirmManualDescription([String? raw]) {
    final current = _state;
    final draft = raw ??
        (current is ProductLookupEnteringManualDescription
            ? current.draftDescription
            : '');
    final message = ManualDescription.validationMessage(draft);
    if (message != null) {
      if (current is ProductLookupEnteringManualDescription) {
        _setState(
          ProductLookupEnteringManualDescription(
            barcode: current.barcode,
            draftDescription: draft,
          ),
        );
      }
      return message;
    }

    try {
      final unresolved = UnresolvedProduct(
        manualDescription: draft,
        barcode: _cascadeBarcodeFromState() ?? _cascadeBarcode,
      );
      _lastUnresolved = unresolved;
      _lastFoundProduct = null;
      _setState(ProductLookupUnresolvedReady(unresolved));
      return null;
    } on ArgumentError catch (error) {
      return error.message?.toString() ?? 'Descripción inválida.';
    }
  }

  void markPendingLineSubmitted(UnresolvedProduct unresolved) {
    _lastUnresolved = unresolved;
    _setState(ProductLookupPendingLineSubmitted(unresolved));
  }

  void resetToIdle() {
    _setState(const ProductLookupIdle());
  }

  Future<void> clear() async {
    _lastFoundProduct = null;
    _lastUnresolved = null;
    _cascadeBarcode = null;
    _setState(const ProductLookupIdle());
  }

  /// Prepare for next line after a successful add (resolved or pending).
  Future<void> prepareForNextLine() async {
    await clear();
  }

  String? _cascadeBarcodeFromState() {
    final current = _state;
    return switch (current) {
      ProductLookupNotFound(:final barcode) => barcode,
      ProductLookupLookingUp(:final barcode) => barcode,
      ProductLookupFound(:final barcode) => barcode,
      ProductLookupFailure(:final barcode) => barcode,
      ProductLookupSearchingByDescription(:final barcode) => barcode,
      ProductLookupSearchResults(:final barcode) => barcode,
      ProductLookupSearchEmpty(:final barcode) => barcode,
      ProductLookupEnteringManualDescription(:final barcode) => barcode,
      ProductLookupUnresolvedReady(:final unresolved) => unresolved.barcode,
      ProductLookupPendingLineSubmitted(:final unresolved) =>
        unresolved.barcode,
      _ => _cascadeBarcode,
    };
  }

  void _setState(ProductLookupState next) {
    _state = next;
    notifyListeners();
  }
}
