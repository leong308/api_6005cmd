import 'package:api_6005cmd/app/theme/app_palette.dart';
import 'package:api_6005cmd/core/config/mapbox_config.dart';
import 'package:api_6005cmd/core/config/mapbox_style_loader.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:pointer_interceptor/pointer_interceptor.dart';

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
    this.initialPitch = 48,
    this.initialBearing = -12,
    this.onTap,
  });

  static const attribution = '\u00a9 Mapbox \u00a9 OpenStreetMap';

  final double centerLatitude;
  final double centerLongitude;
  final double initialZoom;
  final double minZoom;
  final double maxZoom;
  final List<FreeVectorMapPoint> markers;
  final List<FreeVectorMapPoint> route;
  final List<FreeVectorMapRoute> routes;
  final bool fitToBounds;
  final double initialPitch;
  final double initialBearing;
  final void Function(double latitude, double longitude)? onTap;

  @override
  State<FreeVectorMap> createState() => _FreeVectorMapState();
}

class _FreeVectorMapState extends State<FreeVectorMap> {
  ml.MapLibreMapController? _controller;
  _MapboxStyle _style = _MapboxStyle.streets;
  late Future<String> _styleFuture;
  bool _styleLoaded = false;
  bool _threeDimensional = true;
  late double _lastThreeDimensionalBearing;
  int _annotationRevision = 0;

  @override
  void initState() {
    super.initState();
    _lastThreeDimensionalBearing = widget.initialBearing;
    _styleFuture = _loadStyle();
  }

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
    if (!MapboxConfig.isConfigured) {
      return const _MapboxConfigurationError();
    }

    return FutureBuilder<String>(
      future: _styleFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _MapboxStyleError(
            message: snapshot.error.toString(),
            onRetry: _retryStyle,
          );
        }
        if (!snapshot.hasData) {
          return const ColoredBox(
            color: Color(0xffeef3f6),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final style = _style;
        return Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              GestureBinding.instance.pointerSignalResolver.register(
                event,
                (_) {},
              );
            }
          },
          child: Stack(
            children: [
              ml.MapLibreMap(
                key: ValueKey(style.styleId),
                styleString: snapshot.requireData,
                initialCameraPosition: ml.CameraPosition(
                  target: ml.LatLng(
                    widget.centerLatitude,
                    widget.centerLongitude,
                  ),
                  zoom: widget.initialZoom,
                  tilt: _threeDimensional ? widget.initialPitch : 0,
                  bearing: _threeDimensional ? _lastThreeDimensionalBearing : 0,
                ),
                minMaxZoomPreference: ml.MinMaxZoomPreference(
                  widget.minZoom,
                  widget.maxZoom,
                ),
                rotateGesturesEnabled: _threeDimensional,
                tiltGesturesEnabled: _threeDimensional,
                trackCameraPosition: true,
                doubleClickZoomEnabled: true,
                scaleControlEnabled: true,
                scaleControlPosition: ml.ScaleControlPosition.bottomLeft,
                scaleControlUnit: ml.ScaleControlUnit.metric,
                logoEnabled: false,
                attributionButtonPosition:
                    ml.AttributionButtonPosition.bottomRight,
                foregroundLoadColor: AppPalette.whiteA(0.1),
                onMapCreated: (controller) {
                  if (_style != style) {
                    return;
                  }
                  _controller = controller;
                  if (mounted) {
                    setState(() {});
                  }
                },
                onStyleLoadedCallback: () {
                  if (_style != style) {
                    return;
                  }
                  if (mounted) {
                    setState(() {
                      _styleLoaded = true;
                    });
                  }
                  _redrawAnnotations();
                  if (widget.fitToBounds) {
                    _fitToBounds();
                  }
                },
                onCameraMove: (position) {
                  if (_threeDimensional) {
                    _lastThreeDimensionalBearing = position.bearing;
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
                child: PointerInterceptor(
                  child: _MapZoomControls(
                    enabled: _controller != null && _styleLoaded,
                    threeDimensional: _threeDimensional,
                    onZoomIn: () => _zoomBy(1),
                    onZoomOut: () => _zoomBy(-1),
                    onFit: widget.fitToBounds ? _fitToBounds : _moveToCenter,
                    onRotateLeft: () => _rotateOrientation(-30),
                    onResetOrientation: _resetOrientation,
                    onRotateRight: () => _rotateOrientation(30),
                    onThreeDimensional: _toggleThreeDimensional,
                    onStyle: _cycleStyle,
                    styleLabel: _style.label,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String> _loadStyle() {
    return MapboxStyleLoader.load(
      styleId: _style.styleId,
      accessToken: MapboxConfig.accessToken,
    );
  }

  void _retryStyle() {
    setState(() {
      _controller = null;
      _styleLoaded = false;
      _styleFuture = _loadStyle();
    });
  }

  Future<void> _toggleThreeDimensional() async {
    final controller = _controller;
    if (controller == null || !_styleLoaded) {
      return;
    }
    final nextValue = !_threeDimensional;
    if (!nextValue) {
      _lastThreeDimensionalBearing =
          controller.cameraPosition?.bearing ?? _lastThreeDimensionalBearing;
    }
    setState(() {
      _threeDimensional = nextValue;
    });
    await controller.animateCamera(
      ml.CameraUpdate.tiltTo(nextValue ? widget.initialPitch : 0),
      duration: const Duration(milliseconds: 320),
    );
    await controller.animateCamera(
      ml.CameraUpdate.bearingTo(nextValue ? _lastThreeDimensionalBearing : 0),
      duration: const Duration(milliseconds: 260),
    );
  }

  Future<void> _rotateOrientation(double degrees) async {
    final controller = _controller;
    if (controller == null || !_styleLoaded || !_threeDimensional) {
      return;
    }
    final currentBearing =
        controller.cameraPosition?.bearing ?? _lastThreeDimensionalBearing;
    final nextBearing = _normaliseBearing(currentBearing + degrees);
    _lastThreeDimensionalBearing = nextBearing;
    await controller.animateCamera(
      ml.CameraUpdate.bearingTo(nextBearing),
      duration: const Duration(milliseconds: 220),
    );
  }

  Future<void> _resetOrientation() async {
    final controller = _controller;
    if (controller == null || !_styleLoaded || !_threeDimensional) {
      return;
    }
    _lastThreeDimensionalBearing = 0;
    await controller.animateCamera(
      ml.CameraUpdate.bearingTo(0),
      duration: const Duration(milliseconds: 240),
    );
  }

  Future<void> _redrawAnnotations() async {
    final controller = _controller;
    if (!_styleLoaded || controller == null) {
      return;
    }
    final revision = ++_annotationRevision;

    await controller.clearLines();
    if (!_isCurrentAnnotationRevision(controller, revision)) {
      return;
    }
    await controller.clearCircles();
    if (!_isCurrentAnnotationRevision(controller, revision)) {
      return;
    }

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
      if (!_isCurrentAnnotationRevision(controller, revision)) {
        return;
      }
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

  bool _isCurrentAnnotationRevision(
    ml.MapLibreMapController controller,
    int revision,
  ) {
    return mounted &&
        identical(_controller, controller) &&
        _styleLoaded &&
        _annotationRevision == revision;
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
    if (controller == null || !_styleLoaded) {
      return;
    }
    await controller.animateCamera(
      amount > 0 ? ml.CameraUpdate.zoomIn() : ml.CameraUpdate.zoomOut(),
      duration: const Duration(milliseconds: 180),
    );
  }

  void _cycleStyle() {
    setState(() {
      _controller = null;
      _styleLoaded = false;
      _style = _style.next;
      _styleFuture = _loadStyle();
    });
  }
}

class _MapboxConfigurationError extends StatelessWidget {
  const _MapboxConfigurationError();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppPalette.inkA(0.06),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(
            'Mapbox is not configured. Set MAPBOX_ACCESS_TOKEN in '
            'web/mapbox_config.json or build with --dart-define.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppPalette.inkA(0.7)),
          ),
        ),
      ),
    );
  }
}

class _MapboxStyleError extends StatelessWidget {
  const _MapboxStyleError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppPalette.coralA(0.06),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.map_outlined, color: AppPalette.coral),
              const SizedBox(height: 8),
              Text(
                'Could not load the Mapbox vector style.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapZoomControls extends StatelessWidget {
  const _MapZoomControls({
    required this.enabled,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFit,
    required this.onRotateLeft,
    required this.onResetOrientation,
    required this.onRotateRight,
    required this.onThreeDimensional,
    required this.onStyle,
    required this.styleLabel,
    required this.threeDimensional,
  });

  final bool enabled;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFit;
  final VoidCallback onRotateLeft;
  final VoidCallback onResetOrientation;
  final VoidCallback onRotateRight;
  final VoidCallback onThreeDimensional;
  final VoidCallback onStyle;
  final String styleLabel;
  final bool threeDimensional;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppPalette.whiteA(0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppPalette.inkA(0.14)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
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
                tooltip: threeDimensional
                    ? 'Switch to 2D view'
                    : 'Switch to 3D view',
                icon: threeDimensional
                    ? Icons.view_in_ar_rounded
                    : Icons.map_rounded,
                enabled: enabled,
                onPressed: onThreeDimensional,
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
          if (threeDimensional) ...[
            Divider(height: 1, color: AppPalette.inkA(0.12)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MapControlButton(
                  tooltip: 'Rotate view left',
                  icon: Icons.rotate_left_rounded,
                  enabled: enabled,
                  onPressed: onRotateLeft,
                ),
                _MapControlDivider(),
                _MapControlButton(
                  tooltip: 'Face north',
                  icon: Icons.navigation_rounded,
                  enabled: enabled,
                  onPressed: onResetOrientation,
                ),
                _MapControlDivider(),
                _MapControlButton(
                  tooltip: 'Rotate view right',
                  icon: Icons.rotate_right_rounded,
                  enabled: enabled,
                  onPressed: onRotateRight,
                ),
              ],
            ),
          ],
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

enum _MapboxStyle {
  streets('Streets', 'streets-v12'),
  outdoors('Outdoors', 'outdoors-v12'),
  light('Light', 'light-v11');

  const _MapboxStyle(this.label, this.styleId);

  final String label;
  final String styleId;

  _MapboxStyle get next {
    final styles = _MapboxStyle.values;
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

double _normaliseBearing(double bearing) {
  final normalised = bearing % 360;
  return normalised < 0 ? normalised + 360 : normalised;
}

String _mapSignature(FreeVectorMap widget) {
  final markerSignature = widget.markers
      .map(
        (point) =>
            '${point.latitude.toStringAsFixed(6)},'
            '${point.longitude.toStringAsFixed(6)},'
            '${point.color.toARGB32()},${point.radius}',
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
