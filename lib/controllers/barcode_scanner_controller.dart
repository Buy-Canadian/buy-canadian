import 'package:mobile_scanner/mobile_scanner.dart';

typedef BarcodeCallback = void Function(String barcode);

class BarcodeScannerController {
  // Wrap the MobileScannerController.
  final MobileScannerController mobileScannerController =
      MobileScannerController();

  /// Start listening for barcodes.
  void startScanning({required BarcodeCallback onBarcodeScanned}) {
    mobileScannerController.barcodes.listen((barcodeCapture) {
      final codes = barcodeCapture.barcodes;
      if (codes.isEmpty) return;
      final code = codes.first.rawValue ?? '';
      if (code.isNotEmpty) {
        onBarcodeScanned(code);
      }
    });
    mobileScannerController.start();
  }

  Future<void> start() async {
    await mobileScannerController.start();
  }

  Future<void> stop() async {
    await mobileScannerController.stop();
  }

  void toggleTorch() {
    mobileScannerController.toggleTorch();
  }

  void dispose() {
    mobileScannerController.dispose();
  }
}
