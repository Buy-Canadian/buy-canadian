import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:openfoodfacts/openfoodfacts.dart';

import '../models/custom_product_model.dart';
import '../services/openfoodfacts_service.dart';

class ProductController extends ChangeNotifier {
  CustomProductModel? product;
  CustomProductModel? productDraft;
  bool isNewProduct = false;
  bool isLoading = false;
  bool isSubmitting = false;
  String? errorMessage;

  // Controllers for login credentials
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  /// Fetch product info from the service. If not found, create a new draft.
  Future<void> fetchProductInfo(String barcode) async {
    isLoading = true;
    errorMessage = null;
    product = null;
    isNewProduct = false;
    isSubmitting = false;
    notifyListeners();

    try {
      final result = await OpenFoodfactsService.getProductInfo(barcode);
      if (result == null) {
        // No product exists; create a draft with Canada as the default origin.
        productDraft = CustomProductModel(
          barcode: barcode,
          productName: '',
          brands: '',
          origins: 'Canada',
          manufacturingPlaces: '',
          countries: 'Canada',
          countriesTags: [],
          language: OpenFoodFactsLanguage.ENGLISH,
        );
        isNewProduct = true;
      } else {
        productDraft = CustomProductModel.fromProduct(result);
      }
      product = productDraft;
    } catch (e) {
      errorMessage = 'Error fetching product: ${e.toString()}';
    }
    isLoading = false;
    notifyListeners();
  }

  /// Submit the product (create new or update existing).
  Future<bool> submitProduct(FlutterSecureStorage storage) async {
    final email = await storage.read(key: 'off_email');
    final password = await storage.read(key: 'off_password');

    // Credentials must be present.
    if (email == null || password == null) return false;

    isSubmitting = true;
    notifyListeners();
    try {
      final user = User(userId: email, password: password);
      final status = await OpenFoodfactsService.saveProduct(productDraft!.toProduct(), user);
      if (status.status == 1) {
        return true;
      }
    } catch (e) {
      // On error, clear stored credentials.
      await storage.delete(key: 'off_email');
      await storage.delete(key: 'off_password');
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
    return false;
  }

  /// Update a field in the product draft.
  void updateDraft(String fieldKey, dynamic value) {
    if (productDraft != null) {
      productDraft = productDraft!.copyWithField(fieldKey, value);
      product = productDraft;
      notifyListeners();
    }
  }

  /// Reset product data.
  void reset() {
    product = null;
    productDraft = null;
    errorMessage = null;
    isNewProduct = false;
    notifyListeners();
  }

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
