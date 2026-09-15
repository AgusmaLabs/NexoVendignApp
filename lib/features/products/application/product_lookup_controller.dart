import 'package:flutter/foundation.dart';

import '../../../core/authentication/session_service.dart';
import '../../../core/device/barcode_scanner.dart';
import '../../../core/logging/app_logger.dart';
import '../../replenishment/application/replenishment_creation_controller.dart';
import '../domain/barcode_input.dart';
import '../domain/product.dart';
import '../domain/product_exception.dart';
import '../domain/product_lookup_service.dart';
import 'product_lookup_state.dart';

/// Scans/enters a barcode and looks up the product in NexoVending.
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

  ProductLookupState get state => _state;

  Product? get lastFoundProduct => _lastFoundProduct;

  bool get isBusy =>
      _state is ProductLookupScanning || _state is ProductLookupLookingUp;

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
      _ => null,
    };
    if (barcode == null || barcode.isEmpty) {
      _setState(const ProductLookupIdle());
      return;
    }
    await lookup(barcode);
  }

  void resetToIdle() {
    _setState(const ProductLookupIdle());
  }

  Future<void> clear() async {
    _lastFoundProduct = null;
    _setState(const ProductLookupIdle());
  }

  void _setState(ProductLookupState next) {
    _state = next;
    notifyListeners();
  }
}
