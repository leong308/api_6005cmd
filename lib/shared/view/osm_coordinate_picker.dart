import 'package:api_6005cmd/app/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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
    final center = LatLng(latitude, longitude);
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
          'Tap on map to pin exact location.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppPalette.inkA(0.62),
              ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: height,
            child: FlutterMap(
              key: ValueKey(
                '${latitude.toStringAsFixed(5)},${longitude.toStringAsFixed(5)}',
              ),
              options: MapOptions(
                initialCenter: center,
                initialZoom: 12,
                minZoom: 2,
                maxZoom: 18,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onTap: (_, point) {
                  onCoordinateSelected(point.latitude, point.longitude);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.api_6005cmd.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: center,
                      width: 44,
                      height: 44,
                      child: Icon(
                        Icons.location_on_rounded,
                        color: AppPalette.coral,
                        size: 36,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Map data © OpenStreetMap contributors © CARTO',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppPalette.inkA(0.55),
                ),
          ),
        ),
      ],
    );
  }
}

class _CoordinateValue extends StatelessWidget {
  const _CoordinateValue({
    required this.label,
    required this.value,
  });

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
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppPalette.inkA(0.62),
                ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
