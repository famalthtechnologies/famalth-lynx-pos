import 'package:flutter/material.dart';
import 'outlet_detail_modification_screen.dart';

/// Legacy PropertyInfoScreen redirected to OutletDetailModificationScreen
/// All store configuration, tax details, address, state selection, branding,
/// and print visibility settings are now unified in a single comprehensive window.
class PropertyInfoScreen extends StatelessWidget {
  final int outletid;
  const PropertyInfoScreen({super.key, required this.outletid});

  @override
  Widget build(BuildContext context) {
    return const OutletDetailModificationScreen();
  }
}
