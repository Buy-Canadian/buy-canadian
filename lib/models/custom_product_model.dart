import 'package:openfoodfacts/openfoodfacts.dart';

class CustomProductModel {
  final String? barcode;
  final String productName;
  final String brands;
  final String origins;
  final String manufacturingPlaces;
  final String countries;
  final List<String> countriesTags;
  final OpenFoodFactsLanguage language;

  CustomProductModel({
    this.barcode,
    required this.productName,
    required this.brands,
    required this.origins,
    required this.manufacturingPlaces,
    required this.countries,
    required this.countriesTags,
    required this.language,
  });

  factory CustomProductModel.fromProduct(Product product) {
    final json = product.toJson();
    return CustomProductModel(
      barcode: product.barcode,
      productName: json['product_name'] ?? '',
      brands: json['brands'] ?? '',
      origins: json['origins'] ?? '',
      manufacturingPlaces: json['manufacturing_places'] ?? '',
      countries: json['countries'] ?? '',
      countriesTags: (json['countries_tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      // Provide a default language if product.lang is null.
      language: product.lang ?? OpenFoodFactsLanguage.ENGLISH,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'barcode': barcode,
      'product_name': productName,
      'brands': brands,
      'origins': origins,
      'manufacturing_places': manufacturingPlaces,
      'countries': countries,
      'countries_tags': countriesTags,
      'lang': language,
    };
  }

  CustomProductModel copyWithField(String fieldKey, dynamic value) {
    final json = toJson();
    json[fieldKey] = value;
    return CustomProductModel.fromProduct(Product.fromJson(json));
  }

  // New: Convert the custom model back into an OpenFoodFacts Product.
  Product toProduct() {
    return Product.fromJson(toJson());
  }
}
