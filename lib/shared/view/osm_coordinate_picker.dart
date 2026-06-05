import 'package:api_6005cmd/app/theme/app_palette.dart';
import 'package:api_6005cmd/shared/view/free_vector_map.dart';
import 'package:flutter/material.dart';

class OsmCoordinatePicker extends StatelessWidget {
  const OsmCoordinatePicker({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.onCoordinateSelected,
    this.height = 250,
  });

  final double latitude;
  final double longitude;
  final void Function(double latitude, double longitude) onCoordinateSelected;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _CoordinateValue(
                label: 'Latitude',
                value: latitude.toStringAsFixed(6),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _CoordinateValue(
                label: 'Longitude',
                value: longitude.toStringAsFixed(6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Tap on the OpenFreeMap vector map to pin the exact location.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppPalette.inkA(0.62)),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: height,
            child: FreeVectorMap(
              key: ValueKey(
                '${latitude.toStringAsFixed(5)},${longitude.toStringAsFixed(5)}',
              ),
              centerLatitude: latitude,
              centerLongitude: longitude,
              initialZoom: 16,
              markers: [
                FreeVectorMapPoint(
                  latitude: latitude,
                  longitude: longitude,
                  color: AppPalette.coral,
                  radius: 9,
                ),
              ],
              onTap: onCoordinateSelected,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            FreeVectorMap.attribution,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppPalette.inkA(0.55)),
          ),
        ),
      ],
    );
  }
}

class _CoordinateValue extends StatelessWidget {
  const _CoordinateValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppPalette.whiteA(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.inkA(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppPalette.inkA(0.62)),
          ),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
