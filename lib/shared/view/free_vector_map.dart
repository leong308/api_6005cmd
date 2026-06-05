import 'package:api_6005cmd/app/theme/app_palette.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

class FreeVectorMapPoint {
  const FreeVectorMapPoint({
    required this.latitude,
    required this.longitude,
    this.color = AppPalette.coral,
    this.radius = 8,
  });

  final double latitude;
  final double longitude;
  final Color color;
  final double radius;
}

class FreeVectorMapRoute {
  const FreeVectorMapRoute({
    required this.points,
    this.color = AppPalette.blue,
    this.width = 5,
    this.opacity = 0.95,
  });

  final List<FreeVectorMapPoint> points;
  final Color color;
  final double width;
  final double opacity;
}

class FreeVectorMap extends StatefulWidget {
  const FreeVectorMap({
    super.key,
    required this.centerLatitude,
    required this.centerLongitude,
    this.initialZoom = 15,
    this.minZoom = 2,
    this.maxZoom = 22,
    this.markers = const [],
    this.route = const [],
    this.routes = const [],
    this.fitToBounds = false,
    this.onTap,
  });

  static const attribution =
      'OpenFreeMap | OpenMapTiles | OpenStreetMap contributors';

  final double centerLatitude;
  final double centerLongitude;
  final double initialZoom;
  final double minZoom;
  final double maxZoom;
  final List<FreeVectorMapPoint> markers;
  final List<FreeVectorMapPoint> route;
  final List<FreeVectorMapRoute> routes;
  final bool fitToBounds;
  final void Function(double latitude, double longitude)? onTap;

  @override
  State<FreeVectorMap> createState() => _FreeVectorMapState();
}

class _FreeVectorMapState extends State<FreeVectorMap> {
  ml.MapLibreMapController? _controller;
  _FreeVectorMapStyle _style = _FreeVectorMapStyle.liberty;
  bool _styleLoaded = false;

  @override
  void didUpdateWidget(covariant FreeVectorMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_mapSignature(oldWidget) != _mapSignature(widget)) {
      _redrawAnnotations();
      if (widget.fitToBounds) {
        _fitToBounds();
      } else {
        _moveToCenter();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          GestureBinding.instance.pointerSignalResolver.register(event, (_) {});
        }
      },
      child: Stack(
        children: [
          ml.MapLibreMap(
            key: ValueKey(_style.url),
            styleString: _style.url,
            initialCameraPosition: ml.CameraPosition(
              target: ml.LatLng(widget.centerLatitude, widget.centerLongitude),
              zoom: widget.initialZoom,
            ),
            minMaxZoomPreference: ml.MinMaxZoomPreference(
              widget.minZoom,
              widget.maxZoom,
            ),
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
            doubleClickZoomEnabled: true,
            scaleControlEnabled: true,
            scaleControlPosition: ml.ScaleControlPosition.bottomLeft,
            scaleControlUnit: ml.ScaleControlUnit.metric,
            logoEnabled: false,
            attributionButtonPosition: ml.AttributionButtonPosition.bottomRight,
            foregroundLoadColor: AppPalette.whiteA(0.1),
            onMapCreated: (controller) {
              _controller = controller;
              if (mounted) {
                setState(() {});
              }
            },
            onStyleLoadedCallback: () {
              _styleLoaded = true;
              _redrawAnnotations();
              if (widget.fitToBounds) {
                _fitToBounds();
              }
            },
            onMapClick: widget.onTap == null
                ? null
                : (_, coordinates) => widget.onTap!(
                    coordinates.latitude,
                    coordinates.longitude,
                  ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: _MapZoomControls(
              enabled: _controller != null,
              onZoomIn: () => _zoomBy(1),
              onZoomOut: () => _zoomBy(-1),
              onFit: widget.fitToBounds ? _fitToBounds : _moveToCenter,
              onStyle: _cycleStyle,
              styleLabel: _style.label,
            ),
          ),
          Positioned(
            left: 10,
            bottom: 10,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppPalette.whiteA(0.86),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppPalette.inkA(0.12)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                child: Text(
                  'OpenFreeMap vector map',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppPalette.inkA(0.66),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _redrawAnnotations() async {
    final controller = _controller;
    if (!_styleLoaded || controller == null) {
      return;
    }

    await controller.clearLines();
    await controller.clearCircles();

    for (final route in _mapRoutes(widget)) {
      if (route.points.length < 2) {
        continue;
      }
      await controller.addLine(
        ml.LineOptions(
          geometry: route.points.map(_toMapLibrePoint).toList(),
          lineColor: _hexColor(route.color),
          lineOpacity: route.opacity,
          lineWidth: route.width,
          lineJoin: 'round',
        ),
      );
    }

    if (widget.markers.isNotEmpty) {
      await controller.addCircles(
        widget.markers
            .map(
              (point) => ml.CircleOptions(
                geometry: _toMapLibrePoint(point),
                circleColor: _hexColor(point.color),
                circleRadius: point.radius,
                circleStrokeColor: '#ffffff',
                circleStrokeWidth: 2.5,
                circleStrokeOpacity: 0.95,
              ),
            )
            .toList(),
      );
    }
  }

  Future<void> _moveToCenter() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    await controller.animateCamera(
      ml.CameraUpdate.newLatLngZoom(
        ml.LatLng(widget.centerLatitude, widget.centerLongitude),
        widget.initialZoom,
      ),
      duration: const Duration(milliseconds: 260),
    );
  }

  Future<void> _fitToBounds() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    final points = [
      ..._mapRoutes(widget).expand((route) => route.points),
      ...widget.markers,
    ];
    if (points.isEmpty) {
      await _moveToCenter();
      return;
    }
    if (points.length == 1) {
      await controller.animateCamera(
        ml.CameraUpdate.newLatLngZoom(_toMapLibrePoint(points.first), 18),
        duration: const Duration(milliseconds: 260),
      );
      return;
    }

    final bounds = _boundsFor(points);
    await controller.animateCamera(
      ml.CameraUpdate.newLatLngBounds(
        bounds,
        left: 42,
        top: 42,
        right: 42,
        bottom: 42,
      ),
      duration: const Duration(milliseconds: 260),
    );
  }

  Future<void> _zoomBy(double amount) async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    await controller.animateCamera(
      ml.CameraUpdate.zoomBy(amount),
      duration: const Duration(milliseconds: 180),
    );
  }

  void _cycleStyle() {
    setState(() {
      _styleLoaded = false;
      _style = _style.next;
    });
  }
}

class _MapZoomControls extends StatelessWidget {
  const _MapZoomControls({
    required this.enabled,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFit,
    required this.onStyle,
    required this.styleLabel,
  });

  final bool enabled;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFit;
  final VoidCallback onStyle;
  final String styleLabel;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppPalette.whiteA(0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppPalette.inkA(0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MapControlButton(
            tooltip: 'Zoom in',
            icon: Icons.add_rounded,
            enabled: enabled,
            onPressed: onZoomIn,
          ),
          _MapControlDivider(),
          _MapControlButton(
            tooltip: 'Zoom out',
            icon: Icons.remove_rounded,
            enabled: enabled,
            onPressed: onZoomOut,
          ),
          _MapControlDivider(),
          _MapControlButton(
            tooltip: 'Fit map',
            icon: Icons.center_focus_strong_rounded,
            enabled: enabled,
            onPressed: onFit,
          ),
          _MapControlDivider(),
          _MapControlButton(
            tooltip: 'Switch map style: $styleLabel',
            icon: Icons.layers_rounded,
            enabled: enabled,
            onPressed: onStyle,
          ),
        ],
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.tooltip,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 34,
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        iconSize: 18,
        color: AppPalette.inkA(enabled ? 0.78 : 0.32),
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon),
      ),
    );
  }
}

class _MapControlDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: VerticalDivider(width: 1, color: AppPalette.inkA(0.12)),
    );
  }
}

enum _FreeVectorMapStyle {
  liberty('Liberty', 'https://tiles.openfreemap.org/styles/liberty'),
  bright('Bright', 'https://tiles.openfreemap.org/styles/bright'),
  positron('Positron', 'https://tiles.openfreemap.org/styles/positron');

  const _FreeVectorMapStyle(this.label, this.url);

  final String label;
  final String url;

  _FreeVectorMapStyle get next {
    final styles = _FreeVectorMapStyle.values;
    return styles[(index + 1) % styles.length];
  }
}

ml.LatLng _toMapLibrePoint(FreeVectorMapPoint point) {
  return ml.LatLng(point.latitude, point.longitude);
}

List<FreeVectorMapRoute> _mapRoutes(FreeVectorMap widget) {
  return [
    if (widget.route.isNotEmpty)
      FreeVectorMapRoute(points: widget.route, color: AppPalette.blue),
    ...widget.routes,
  ];
}

ml.LatLngBounds _boundsFor(List<FreeVectorMapPoint> points) {
  var minLat = points.first.latitude;
  var maxLat = points.first.latitude;
  var minLng = points.first.longitude;
  var maxLng = points.first.longitude;

  for (final point in points.skip(1)) {
    minLat = point.latitude < minLat ? point.latitude : minLat;
    maxLat = point.latitude > maxLat ? point.latitude : maxLat;
    minLng = point.longitude < minLng ? point.longitude : minLng;
    maxLng = point.longitude > maxLng ? point.longitude : maxLng;
  }

  return ml.LatLngBounds(
    southwest: ml.LatLng(minLat, minLng),
    northeast: ml.LatLng(maxLat, maxLng),
  );
}

String _hexColor(Color color) {
  final value = color.toARGB32() & 0x00ffffff;
  return '#${value.toRadixString(16).padLeft(6, '0')}';
}

String _mapSignature(FreeVectorMap widget) {
  final markerSignature = widget.markers
      .map(
        (point) =>
            '${point.latitude.toStringAsFixed(6)},${point.longitude.toStringAsFixed(6)},${point.radius}',
      )
      .join('|');
  final routeSignature = _mapRoutes(widget)
      .map(
        (route) => [
          route.color.toARGB32(),
          route.width.toStringAsFixed(2),
          route.opacity.toStringAsFixed(2),
          route.points
              .map(
                (point) =>
                    '${point.latitude.toStringAsFixed(6)},${point.longitude.toStringAsFixed(6)}',
              )
              .join(','),
        ].join(':'),
      )
      .join('|');
  return [
    widget.centerLatitude.toStringAsFixed(6),
    widget.centerLongitude.toStringAsFixed(6),
    widget.initialZoom.toStringAsFixed(2),
    widget.fitToBounds,
    markerSignature,
    routeSignature,
  ].join(';');
}
