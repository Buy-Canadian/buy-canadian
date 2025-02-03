import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:openfoodfacts/openfoodfacts.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:validators/validators.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    OpenFoodAPIConfiguration.userAgent = UserAgent(
      name: 'Buy Canadian',
    );

    return MaterialApp(
      title: 'Buy Canadian',
      theme: ThemeData(
        primarySwatch: Colors.red,
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
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final KeyboardVisibilityController _keyboardController =
      KeyboardVisibilityController();
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

    _fetchProductInfo(barcode);
  }

  Future<void> _fetchProductInfo(String barcode) async {
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
        title: const Text('Buy Canadian'),
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
                    return const Icon(Icons.flash_auto, color: Colors.grey);
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

  Map<String, dynamic> _parseProductInfo(Product product) {
    final hasOriginsNote =
        product.statesTags?.contains('en:origins-to-be-completed') ?? false;
    final originsNote =
        hasOriginsNote ? '\n(Note: Origins information may be incomplete)' : '';

    // Helper function to handle null/empty list conversion
    List<String> parseList(dynamic value) {
      if (value is String) {
        return value
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      return ['Not available'];
    }

    // Check for Canadian origins
    final rawOrigins = product.origins ?? '';
    final originsList = rawOrigins
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final isCanadian =
        originsList.any((origin) => origin.toUpperCase() == "CANADA");

    return {
      'product_name': (product.productName?.isEmpty ?? true)
          ? 'Not available'
          : product.productName!,
      'brands':
          (product.brands?.isEmpty ?? true) ? 'Not available' : product.brands!,
      'origins':
          '${(product.origins?.isEmpty ?? true) ? 'Not available' : product.origins!}$originsNote',
      'manufacturing_places': (product.manufacturingPlaces?.isEmpty ?? true)
          ? ['Not available']
          : parseList(product.manufacturingPlaces!),
      'countries': (product.countries?.isEmpty ?? true)
          ? ['Not available']
          : parseList(product.countries!),
      'countries_tags': (product.countriesTags?.isEmpty ?? true)
          ? ['Not available']
          : product.countriesTags!,
      'is_canadian': isCanadian
    };
  }

  Widget _buildOriginRow(String originText, bool isCanadian, String barcode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Origins',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 32,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          originText,
          style: TextStyle(
            fontSize: 24,
            color: isCanadian ? Colors.red : Colors.black,
            fontWeight: isCanadian ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 12),
        if (!isCanadian)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: OutlinedButton.icon(
              icon: const Text("🇨🇦"),
              label: const Text('This is a Canadian Product'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
              ),
              onPressed: () => _showContributionDialog(barcode, isCanadian),
            ),
          ),
        if (isCanadian)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.edit_location_alt_outlined),
              label: const Text('This is not a Canadian Product!'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
              ),
              onPressed: () => _showContributionDialog(barcode, isCanadian),
            ),
          ),
      ],
    );
  }

  void _showContributionDialog(String barcode, bool isCanadian) {
    const String loginAlertTitleText = 'Contribute to Open Food Facts';
    const String loginPromptText = 'Login to your Open Food Facts account to confirm product origins:';
    const String confirmationText = 'Confirm change of product origin';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(loginAlertTitleText),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  loginPromptText),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _submitEditOrigin(barcode, isCanadian);
            },
            child: const Text(confirmationText,
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildProductDetails() {
    final productInfo = _parseProductInfo(_product!);

    return Column(
      children: [
        if (productInfo['is_canadian'] as bool)
          Lottie.asset(
            'assets/canada_flag.json',
            width: 200,
            height: 150,
            fit: BoxFit.contain,
            repeat: true,
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildInfoRow('Product Name', productInfo['product_name']),
              _buildInfoRow('Brands', productInfo['brands']),
              _buildOriginRow(
                productInfo['origins'],
                productInfo['is_canadian'],
                _product!.barcode ?? '',
              ),
              _buildListRow(
                  'Manufacturing Places', productInfo['manufacturing_places']),
              _buildListRow('Countries Sold', productInfo['countries']),
              _buildListRow('Countries Tags', productInfo['countries_tags']),
            ],
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

  Widget _buildInfoRow(String title, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 32,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.toString(),
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildListRow(String title, List<dynamic> items) {
    if (items.isEmpty) {
      items = ["No data available"];
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 32,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Text(
                  item.toString().trim(),
                  style: const TextStyle(fontSize: 16),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Future<void> _submitEditOrigin(String barcode, bool isCanadian) async {
    if (!isEmail(_usernameController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }

    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }

    Map<String,dynamic> productJson = _product!.toJson();
    productJson['origins'] = isCanadian ? '' : 'Canada';
    final Product updatedProduct = Product.fromJson(productJson);

    try {
      final Status result = await OpenFoodAPIClient.saveProduct(
        User(
            userId: _usernameController.text.trim(),
            password: _passwordController.text.trim()),
        updatedProduct,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2),
            content: Text(result.status == 1
                ? '🇨🇦 Thank you for contributing!'
                : 'Error: ${result.error}')),
        );

        if (result.status == 1) {
          _product = updatedProduct;
          await _fetchProductInfo(barcode);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed: ${e.toString()}')),
        );
      }
    }
  }
}
