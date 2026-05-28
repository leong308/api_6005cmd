import 'package:api_6005cmd/app/theme/app_palette.dart';
import 'package:flutter/material.dart';

class LayerBadges extends StatelessWidget {
  const LayerBadges({
    super.key,
    required this.dataLayer,
    required this.modelLayer,
    required this.viewLayer,
  });

  final String dataLayer;
  final String modelLayer;
  final String viewLayer;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _layerChip('Data', dataLayer),
        _layerChip('Model', modelLayer),
        _layerChip('View', viewLayer),
      ],
    );
  }

  Widget _layerChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppPalette.mintA(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppPalette.mintA(0.42)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppPalette.inkA(0.9),
        ),
      ),
    );
  }
}
