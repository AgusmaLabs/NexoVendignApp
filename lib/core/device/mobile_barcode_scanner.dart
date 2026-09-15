import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'barcode_scanner.dart';

/// Opens a camera scan page via [navigatorKey] and returns the first barcode.
final class MobileBarcodeScanner implements BarcodeScanner {
  MobileBarcodeScanner({required this.navigatorKey});

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Future<String?> scan() async {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      return null;
    }
    return navigator.push<String>(
      MaterialPageRoute<String>(
        builder: (_) => const BarcodeScanPage(),
        fullscreenDialog: true,
      ),
    );
  }
}

/// Full-screen camera barcode capture for [MobileBarcodeScanner].
class BarcodeScanPage extends StatefulWidget {
  const BarcodeScanPage({super.key});

  @override
  State<BarcodeScanPage> createState() => _BarcodeScanPageState();
}

class _BarcodeScanPageState extends State<BarcodeScanPage> {
  final MobileScannerController _controller = MobileScannerController();
  var _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) {
      return;
    }
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty) {
        _handled = true;
        Navigator.of(context).pop(value);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear código'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: MobileScanner(
        controller: _controller,
        onDetect: _onDetect,
      ),
    );
  }
}
