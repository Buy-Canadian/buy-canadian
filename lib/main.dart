import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:openfoodfacts/openfoodfacts.dart';
import 'package:lottie/lottie.dart';

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
  final _secureStorage = const FlutterSecureStorage();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  MobileScannerController controller = MobileScannerController();
  StreamSubscription<Object?>? _subscription;
  Product? _product;
  Product? _productDraft;
  bool _isNewProduct = false;
  bool _isLoading = false;
  bool _isSubmitting = false;
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
      _product = null;
      _isNewProduct = false;
      _isSubmitting = false;
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
        if (result.product == null) {
          // Product does not exist, create new product draft
          Map<String, dynamic> newProductJson = Product(
                  barcode: barcode,
                  productName: '',
                  brands: '',
                  countries: 'Canada',
                  countriesTags: [],
                  lang: OpenFoodFactsLanguage.ENGLISH)
              .toJson();
          newProductJson['origins'] ??= '';
          newProductJson['manufacturing_places'] ??= '';

          _productDraft = Product.fromJson(newProductJson);
          _isNewProduct = true;
        } else {
          _productDraft = Product.fromJson(result.product!.toJson());
        }
        setState(() {
          _product = _productDraft;
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
        title: const Text('Buy Canadian 🇨🇦',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
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

  Widget _buildProductDetails() {
    final productInfo = _product!.toJson();
    return Column(
      children: [
        if (productInfo['origins'].toString().toUpperCase().contains('CANADA'))
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
              Padding(
                padding: const EdgeInsets.only(top: 16.0, bottom: 16.0),
                child: Text('Product Details:',
                    style: const TextStyle(
                        color: Colors.red,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
              ),
              _buildEditableField(
                  'Product Name', 'product_name', productInfo['product_name']),
              _buildEditableField('Brands', 'brands', productInfo['brands']),
              _buildEditableField('Origins', 'origins', productInfo['origins']),
              _buildEditableField('Manufacturing Places',
                  'manufacturing_places', productInfo['manufacturing_places']),
              _buildEditableField(
                  'Countries Sold', 'countries', productInfo['countries']),
              _buildEditableListField('Countries Tags', 'countries_tags',
                  productInfo['countries_tags']),
              _buildSubmissionFooter()
            ],
          ),
        ),
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

  Widget _buildSubmissionFooter() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          ElevatedButton.icon(
            icon: _isSubmitting
                ? const CircularProgressIndicator()
                : const Icon(Icons.cloud_upload),
            label: Text(_isNewProduct ? 'Create New Product' : 'Save Changes'),
            onPressed: _isSubmitting ? null : _submitProduct,
          ),
          TextButton(
            onPressed: _resetScanner,
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField(String label, String fieldKey, String value,
      {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            initialValue: value,
            decoration: InputDecoration(
              labelText: '$label${isRequired ? ' *' : ''}',
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) => _updateDraft(fieldKey, value),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildEditableListField(
      String label, String fieldKey, List<String> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
              initialValue: items.where((e) => e.isNotEmpty).join(', '),
              decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
                helperText: 'Separate values with commas',
              ),
              onChanged: (value) => _updateDraft(
                  fieldKey,
                  value
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList())),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  void _showLoginDialog(VoidCallback? retryAction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login to your Open Food Facts account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _secureStorage.write(
                key: 'off_email',
                value: _usernameController.text.trim(),
              );
              await _secureStorage.write(
                key: 'off_password',
                value: _passwordController.text.trim(),
              );
              if (retryAction != null) retryAction();
            },
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitProduct() async {
    final email = await _secureStorage.read(key: 'off_email');
    final password = await _secureStorage.read(key: 'off_password');

    if (email == null || password == null) {
      _showLoginDialog(_submitProduct);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final Status result = await OpenFoodAPIClient.saveProduct(
        User(userId: email, password: password),
        _productDraft!,
      );

      if (result.status == 1) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(_isNewProduct
                    ? 'Product created successfully!'
                    : 'Product updated successfully!')),
          );
        }
        await _fetchProductInfo(_productDraft!.barcode!);
      }
    } catch (e) {
      await _secureStorage.write(
        key: 'off_email',
        value: null,
      );
      await _secureStorage.write(
        key: 'off_password',
        value: null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_isNewProduct
                  ? 'Could not create new product'
                  : 'Could not update product info')),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _updateDraft(String fieldKey, dynamic value) {
    setState(() {
      _productDraft = _productDraft!.copyWith(
        toJson: {fieldKey: value},
      );
    });
  }
}

extension ProductCopyWith on Product {
  Product copyWith({Map<String, dynamic>? toJson}) {
    final json = this.toJson();
    json.addAll(toJson ?? {});
    return Product.fromJson(json);
  }
}
