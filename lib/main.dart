import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const QRBarcodeScannerApp());
}

class QRBarcodeScannerApp extends StatelessWidget {
  const QRBarcodeScannerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR & Barcode Scanner',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}