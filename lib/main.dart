import 'package:flutter/material.dart';
import 'package:openfoodfacts/openfoodfacts.dart';
import 'screens/barcode_scanner_screen.dart';

void main() {
  // Set the user agent for Open Food Facts API calls.
  OpenFoodAPIConfiguration.userAgent = UserAgent(name: 'Buy Canadian');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Buy Canadian',
      theme: ThemeData(primarySwatch: Colors.red),
      home: const BarcodeScannerScreen(),
    );
  }
}
