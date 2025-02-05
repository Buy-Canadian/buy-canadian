import 'package:openfoodfacts/openfoodfacts.dart';

class OpenFoodfactsService {
  /// Get product info for a given barcode.
  static Future<Product?> getProductInfo(String barcode) async {
    final result = await OpenFoodAPIClient.getProductV3(
      ProductQueryConfiguration(
        barcode,
        version: ProductQueryVersion.v3,
        fields: ProductField.values,
        language: OpenFoodFactsLanguage.ENGLISH,
      ),
    );
    return result.product;
  }

  /// Save (create/update) the product.
  static Future<Status> saveProduct(Product product, User user) async {
    return await OpenFoodAPIClient.saveProduct(user, product);
  }
}
