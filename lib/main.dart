import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:openfoodfacts/openfoodfacts.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    OpenFoodAPIConfiguration.userAgent = UserAgent(
      name: '<Name of your app>',
    );

    return MaterialApp(
      title: 'Food Scanner',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const BarcodeScannerScreen(),
    );
  }
}

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with WidgetsBindingObserver {
  MobileScannerController controller = MobileScannerController();
  StreamSubscription<Object?>? _subscription;
  Product? _product;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscription = controller.barcodes.listen(_handleBarcode);
    unawaited(controller.start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!controller.value.hasCameraPermission) return;

    switch (state) {
      case AppLifecycleState.resumed:
        _subscription = controller.barcodes.listen(_handleBarcode);
        unawaited(controller.start());
      case AppLifecycleState.inactive:
        _subscription?.cancel();
        _subscription = null;
        unawaited(controller.stop());
      default:
        break;
    }
  }

  Future<void> _handleBarcode(BarcodeCapture barcodes) async {
    final List<Barcode> codes = barcodes.barcodes;
    if (codes.isEmpty) return;
    
    final String barcode = codes.first.rawValue ?? '';
    if (barcode.isEmpty) return;

    // Prevent multiple scans
    if (_isLoading || _product != null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final ProductResultV3 result = await OpenFoodAPIClient.getProductV3(
        ProductQueryConfiguration(
          barcode,
          version: ProductQueryVersion.v3,
          fields: ProductField.values,
          language: OpenFoodFactsLanguage.ENGLISH,
        ),
      );

      if (mounted) {
        setState(() {
          _product = result.product;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error fetching product: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _resetScanner() {
    setState(() {
      _product = null;
      _errorMessage = null;
    });
    unawaited(controller.start());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Scanner'),
        actions: [
          IconButton(
            icon: ValueListenableBuilder<TorchState>(
              valueListenable: ValueNotifier(controller.value.torchState),
              builder: (BuildContext context, TorchState state, child) {
                switch (state) {
                  case TorchState.on:
                    return const Icon(Icons.flash_on, color: Colors.yellow);
                  case TorchState.off:
                    return const Icon(Icons.flash_off, color: Colors.grey);
                  case TorchState.unavailable:
                    return const Icon(Icons.flash_off, color: Colors.grey);
                  case TorchState.auto:
                    return const Icon(Icons.flash_off, color: Colors.grey);
                }
              },
            ),
            onPressed: () => controller.toggleTorch(),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_product != null) {
      return _buildProductDetails();
    }

    return Stack(
      children: [
        MobileScanner(
          controller: controller,
          fit: BoxFit.cover,
        ),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 16),
            ),
          ),
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
    );
  }

  Widget _buildProductDetails() {
    final productJson = _product?.toJson() ?? {};
    final formattedJson = JsonEncoder.withIndent('  ').convert(productJson);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: SelectableText(
              formattedJson,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: _resetScanner,
            child: const Text('Scan Again'),
          ),
        ),
      ],
    );
  }
}