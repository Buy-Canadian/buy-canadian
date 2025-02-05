import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:lottie/lottie.dart';

import '../controllers/barcode_scanner_controller.dart';
import '../controllers/product_controller.dart';
import '../utils/app_lifecycle_handler.dart';
import '../widgets/editable_field.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with WidgetsBindingObserver {
  final _secureStorage = const FlutterSecureStorage();

  // Instantiate our controllers.
  final BarcodeScannerController scannerController =
      BarcodeScannerController();
  final ProductController productController = ProductController();

  // Debug: store the last scanned barcode.
  String? _lastScannedBarcode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Listen for changes from the product controller and rebuild.
    productController.addListener(() => setState(() {}));

    // Start the scanner and pass a callback for when a barcode is detected.
    scannerController.startScanning(onBarcodeScanned: _handleBarcode);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    scannerController.dispose();
    productController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Use our lifecycle helper to start or stop the scanner.
    handleAppLifecycleState(
      state,
      onResume: () => scannerController.start(),
      onInactive: () => scannerController.stop(),
    );
  }

  Future<void> _handleBarcode(String barcode) async {
    // Debug: print and record the scanned barcode.
    print('Barcode scanned: $barcode');
    setState(() {
      _lastScannedBarcode = barcode;
    });

    // Prevent multiple scans if already loading or a product is loaded.
    if (productController.isLoading || productController.product != null) return;

    await productController.fetchProductInfo(barcode);
  }
  Widget _buildProductDetails() {
    final productJson = productController.product?.toJson() ?? {};
    return Column(
      children: [
        // Optionally display an animation if the product originates in Canada.
        if ((productJson['origins'] ?? '')
            .toString()
            .toUpperCase()
            .contains('CANADA'))
          Lottie.asset(
            'assets/canada_flag.json',
            width: 200,
            height: 150,
            fit: BoxFit.contain,
            repeat: true,
          ),
        // Display the product details in a scrollable list.
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // You can reuse your EditableField widget here.
              EditableField(
                label: 'Product Name',
                value: productJson['product_name'] ?? '',
                onChanged: (value) => productController.updateDraft('product_name', value),
              ),
              EditableField(
                label: 'Brands',
                value: productJson['brands'] ?? '',
                onChanged: (value) => productController.updateDraft('brands', value),
              ),
              EditableField(
                label: 'Origins',
                value: productJson['origins'] ?? '',
                onChanged: (value) => productController.updateDraft('origins', value),
              ),
              EditableField(
                label: 'Manufacturing Places',
                value: productJson['manufacturing_places'] ?? '',
                onChanged: (value) => productController.updateDraft('manufacturing_places', value),
              ),
              EditableField(
                label: 'Countries Sold',
                value: productJson['countries'] ?? '',
                onChanged: (value) => productController.updateDraft('countries', value),
              ),
              EditableField(
                label: 'Countries Tags',
                value: (productJson['countries_tags'] as List<dynamic>?)
                        ?.where((e) => e.toString().isNotEmpty)
                        .join(', ') ??
                    '',
                helperText: 'Separate values with commas',
                onChanged: (value) {
                  final list = value
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();
                  productController.updateDraft('countries_tags', list);
                },
              ),
              // Additional fields or UI elements as needed.
            ],
          ),
        ),
        // A button to reset scanning.
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: ElevatedButton(
            onPressed: _resetScanner,
            child: const Text('Scan Again'),
          ),
        ),
      ],
    );
  }
  void _resetScanner() {
    setState(() {
      _lastScannedBarcode = null; // Clear the debug barcode display.
    });
    productController.reset();
    scannerController.start();
  }

  // (Rest of your code such as _submitProduct, _buildProductDetails, etc.)

  @override
  Widget build(BuildContext context) {
    // Show a loading indicator while fetching product info.
    if (productController.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Buy Canadian 🇨🇦',
          style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: scannerController.mobileScannerController,
              builder: (context, value, child) {
                // Here we access the current torch state from the controller.
                final torchState =
                    scannerController.mobileScannerController.value.torchState;
                if (torchState == TorchState.on) {
                  return const Icon(Icons.flash_on, color: Colors.yellow);
                } else if (torchState == TorchState.off) {
                  return const Icon(Icons.flash_off, color: Colors.grey);
                } else {
                  return const Icon(Icons.flash_off, color: Colors.grey);
                }
              },
            ),
            onPressed: scannerController.toggleTorch,
          ),
        ],
      ),
      body: productController.product != null
          ? _buildProductDetails()
          : Stack(
              children: [
                MobileScanner(
                  controller: scannerController.mobileScannerController,
                  fit: BoxFit.cover,
                ),
                // If there's an error message, display it.
                if (productController.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      productController.errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                    ),
                  ),
                // Debug: Show the scanned barcode (if any) at the top-center.
                if (_lastScannedBarcode != null)
                  Positioned(
                    top: 20,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(8.0),
                        color: Colors.black54,
                        child: Text(
                          'Scanned Barcode: $_lastScannedBarcode',
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                // The scanning area overlay.
                const Center(
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.fromBorderSide(
                          BorderSide(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
