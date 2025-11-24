import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import '../models/danger_zone.dart';
import '../services/ar_coordinate_system.dart';
import '../services/device_orientation_service.dart';
import '../services/location_service.dart';

class ArDangerZoneView extends StatefulWidget {
  const ArDangerZoneView({
    super.key,
    required this.dangerZones,
    this.currentPosition,
    this.activeZoneIds = const <String>{},
  });

  final List<DangerZone> dangerZones;
  final Position? currentPosition;
  final Set<String> activeZoneIds;

  @override
  State<ArDangerZoneView> createState() => _ArDangerZoneViewState();
}

class _ArMarker {
  const _ArMarker({
    required this.zone,
    required this.position,
    required this.distance,
    required this.scale,
  });

  final DangerZone zone;
  final Offset position;
  final double distance;
  final double scale;
}

class _ArDangerZoneViewState extends State<ArDangerZoneView> {
  static const double _cameraHorizontalFov = 60.0;
  final LocationService _locationService = LocationService.instance;
  final DeviceOrientationService _orientationService =
      DeviceOrientationService.instance;

  late final VoidCallback _locationListener;
  StreamSubscription<OrientationReading>? _orientationSubscription;
  Timer? _arTimer;

  CameraController? _cameraController;
  bool _isCameraInitializing = true;
  String? _cameraError;

  Position? _latestPosition;
  Set<String> _highlightedZoneIds = <String>{};

  OrientationReading _latestOrientation = const OrientationReading(
    yaw: 0,
    pitch: 0,
    roll: 0,
  );
  List<_ArMarker> _markers = <_ArMarker>[];

  @override
  void initState() {
    super.initState();
    _highlightedZoneIds = widget.activeZoneIds.isNotEmpty
        ? Set<String>.from(widget.activeZoneIds)
        : <String>{};
    _latestPosition = widget.currentPosition;

    if (_highlightedZoneIds.isEmpty && _latestPosition != null) {
      _highlightedZoneIds = _resolveActiveZoneIds(_latestPosition!);
    }

    _locationListener = _handleLocationStateChanged;
    _locationService.stateListenable.addListener(_locationListener);

    final LocationState state = _locationService.state;
    if (!state.isLoading && state.position == null) {
      unawaited(_locationService.refresh());
    }

    _initializeCamera();
    _startOrientationTracking();
    _startArLoop();
  }

  @override
  void dispose() {
    _locationService.stateListenable.removeListener(_locationListener);
    _orientationSubscription?.cancel();
    _arTimer?.cancel();
    _cameraController?.dispose();
    _orientationService.stopTracking();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _isCameraInitializing = true;
      _cameraError = null;
    });

    try {
      final PermissionStatus status = await Permission.camera.request();
      if (!status.isGranted) {
        setState(() {
          _cameraError = 'La aplicación necesita permiso para acceder a la cámara.';
          _isCameraInitializing = false;
        });
        return;
      }

      final List<CameraDescription> cameras = await availableCameras();
      CameraDescription? backCamera;

      for (final camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.back) {
          backCamera = camera;
          break;
        }
      }

      backCamera ??= cameras.isNotEmpty ? cameras.first : null;

      if (backCamera == null) {
        setState(() {
          _cameraError = 'No se encontró una cámara trasera disponible.';
          _isCameraInitializing = false;
        });
        return;
      }

      final CameraController controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      await _cameraController?.dispose();
      _cameraController = controller;

      setState(() {
        _isCameraInitializing = false;
      });
    } catch (error) {
      setState(() {
        _cameraError = 'No se pudo inicializar la cámara. Inténtalo nuevamente.';
        _isCameraInitializing = false;
      });
    }
  }

  void _startOrientationTracking() {
    unawaited(_orientationService.startTracking());
    _orientationSubscription =
        _orientationService.orientationStream.listen((OrientationReading reading) {
      setState(() {
        _latestOrientation = reading;
      });
    });
  }

  void _startArLoop() {
    _arTimer?.cancel();
    _arTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      _updateArMarkers();
    });
  }

  void _updateArMarkers() {
    if (!mounted) return;
    final Position? reference = _latestPosition;
    if (reference == null) {
      setState(() {
        _markers = <_ArMarker>[];
      });
      return;
    }

    final Size screenSize = MediaQuery.of(context).size;
    final List<_ArMarker> computed = <_ArMarker>[];

    for (final DangerZone zone in _zonesToDisplay()) {
      final Position target = _positionFromZone(zone, reference.timestamp ?? DateTime.now());
      final vm.Vector3 enu = ArCoordinateSystem.enuFromReference(
        reference: reference,
        target: target,
      );

      final ArMarkerProjection? projection = ArCoordinateSystem.projectToScreen(
        enuPosition: enu,
        yaw: _latestOrientation.yaw,
        pitch: _latestOrientation.pitch,
        roll: _latestOrientation.roll,
        horizontalFovDegrees: _cameraHorizontalFov,
        screenWidth: screenSize.width,
        screenHeight: screenSize.height,
      );

      if (projection == null) {
        continue;
      }

      computed.add(
        _ArMarker(
          zone: zone,
          position: Offset(projection.screenPosition.x, projection.screenPosition.y),
          distance: projection.distance,
          scale: projection.scale,
        ),
      );
    }

    setState(() {
      _markers = computed;
    });
  }

  Position _positionFromZone(DangerZone zone, DateTime timestamp) {
    return Position(
      latitude: zone.center.latitude,
      longitude: zone.center.longitude,
      timestamp: timestamp,
      accuracy: 0,
      altitude: zone.altitude,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
      isMocked: false,
    );
  }

  void _handleLocationStateChanged() {
    final LocationState state = _locationService.state;
    final Position? position = state.position;
    if (position == null) {
      return;
    }

    final Set<String> resolvedIds = _resolveActiveZoneIds(position);
    final bool idsChanged = _setsDiffer(resolvedIds, _highlightedZoneIds);
    final bool altitudeChanged =
        _latestPosition == null || position.altitude != _latestPosition!.altitude;
    final bool locationChanged = _latestPosition == null ||
        position.latitude != _latestPosition!.latitude ||
        position.longitude != _latestPosition!.longitude;

    if (resolvedIds.isNotEmpty) {
      _highlightedZoneIds = resolvedIds;
    } else if (_highlightedZoneIds.isNotEmpty) {
      _highlightedZoneIds = <String>{};
    }

    _latestPosition = position;

    if (mounted && (idsChanged || altitudeChanged || locationChanged)) {
      setState(() {});
    }
  }

  bool _setsDiffer(Set<String> a, Set<String> b) {
    if (a.length != b.length) {
      return true;
    }
    for (final String value in a) {
      if (!b.contains(value)) {
        return true;
      }
    }
    return false;
  }

  Set<String> _resolveActiveZoneIds(Position position) {
    final Set<String> ids = <String>{};
    for (final zone in widget.dangerZones) {
      final double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        zone.center.latitude,
        zone.center.longitude,
      );
      if (distance <= zone.radius) {
        ids.add(zone.id);
      }
    }
    return ids;
  }

  Iterable<DangerZone> _zonesToDisplay() {
    final Set<String> ids = _highlightedZoneIds.isNotEmpty
        ? _highlightedZoneIds
        : widget.activeZoneIds;
    if (ids.isEmpty) {
      return widget.dangerZones;
    }
    return widget.dangerZones.where((zone) => ids.contains(zone.id));
  }

  double? _distanceToZone(DangerZone zone) {
    final Position? position = _latestPosition;
    if (position == null) {
      return null;
    }
    return Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      zone.center.latitude,
      zone.center.longitude,
    );
  }

  Widget _buildCameraPreview() {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    final Size previewSize = controller.value.previewSize ?? const Size(1, 1);

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewSize.width,
          height: previewSize.height,
          child: CameraPreview(controller),
        ),
      ),
    );
  }

  Widget _buildTopOverlay() {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.85),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                '⚠️ ZONA DE PELIGRO DETECTADA',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildZoneInfo(DangerZone zone) {
    final double? distance = _distanceToZone(zone);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.place, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                zone.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: Colors.white70),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Descripción',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    zone.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.dangerous_outlined, color: Colors.white70),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Peligros',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    zone.specificDangers,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.security_outlined, color: Colors.white70),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recomendaciones',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    zone.securityRecommendations,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.straighten, color: Colors.white70),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Distancia',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    distance != null
                        ? '${distance.toStringAsFixed(1)} m'
                        : 'Calculando distancia...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomOverlay() {
    final Iterable<DangerZone> zones = _zonesToDisplay();

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.withOpacity(0.6), width: 1.5),
          ),
          child: zones.isNotEmpty
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shield_outlined, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'Información de Seguridad',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    for (final zone in zones) ...<Widget>[
                      _buildZoneInfo(zone),
                      if (zone != zones.last)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Divider(
                            color: Colors.white.withOpacity(0.2),
                            thickness: 1,
                          ),
                        ),
                    ],
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shield_outlined, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'Información de Seguridad',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No hay zonas de peligro activas cercanas',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                          ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildArPainterLayer() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return CustomPaint(
          painter: _ArMarkerPainter(markers: _markers),
          size: Size(constraints.maxWidth, constraints.maxHeight),
        );
      },
    );
  }

  Widget _buildDebugPanel() {
    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: DefaultTextStyle(
            style: const TextStyle(color: Colors.white, fontSize: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('DEBUG AR'),
                Text('Yaw: ${(vm.degrees(_latestOrientation.yaw)).toStringAsFixed(1)}°'),
                Text('Pitch: ${(vm.degrees(_latestOrientation.pitch)).toStringAsFixed(1)}°'),
                Text('Roll: ${(vm.degrees(_latestOrientation.roll)).toStringAsFixed(1)}°'),
                Text('Marcadores: ${_markers.length}'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Inicializando cámara...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.camera_alt_outlined,
                size: 72,
                color: Colors.white.withOpacity(0.8),
              ),
              const SizedBox(height: 16),
              Text(
                _cameraError ?? 'No se pudo acceder a la cámara.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white,
                    ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _initializeCamera,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraError != null) {
      return _buildError();
    }

    if (_isCameraInitializing || _cameraController == null) {
      return _buildLoading();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildCameraPreview(),
          _buildArPainterLayer(),
          _buildTopOverlay(),
          _buildBottomOverlay(),
          _buildDebugPanel(),
        ],
      ),
    );
  }
}

class _ArMarkerPainter extends CustomPainter {
  _ArMarkerPainter({required this.markers});

  final List<_ArMarker> markers;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint bubblePaint = Paint()
      ..color = Colors.red.withOpacity(0.85)
      ..style = PaintingStyle.fill;

    for (final _ArMarker marker in markers) {
      canvas.save();
      canvas.translate(marker.position.dx, marker.position.dy);
      canvas.scale(marker.scale);

      final double bubbleWidth = 180;
      final double bubbleHeight = 70;
      final Rect rect = Rect.fromCenter(
        center: Offset.zero,
        width: bubbleWidth,
        height: bubbleHeight,
      );

      final RRect rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));
      canvas.drawRRect(rrect, bubblePaint);

      final TextPainter iconPainter = TextPainter(
        text: const TextSpan(
          text: '⚠️',
          style: TextStyle(fontSize: 18),
        ),
        textDirection: TextDirection.ltr,
      )
        ..layout();
      iconPainter.paint(canvas, Offset(-bubbleWidth / 2 + 12, -bubbleHeight / 2 + 10));

      final TextPainter titlePainter = TextPainter(
        text: TextSpan(
          text: marker.zone.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )
        ..layout(maxWidth: bubbleWidth - 50);
      titlePainter.paint(canvas, Offset(-bubbleWidth / 2 + 40, -bubbleHeight / 2 + 8));

      final TextPainter distancePainter = TextPainter(
        text: TextSpan(
          text: '${marker.distance.toStringAsFixed(1)} m',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )
        ..layout(maxWidth: bubbleWidth - 30);
      distancePainter.paint(canvas, Offset(-bubbleWidth / 2 + 12, -bubbleHeight / 2 + 32));

      final TextPainter detailPainter = TextPainter(
        text: TextSpan(
          text: marker.zone.specificDangers,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '…',
      )
        ..layout(maxWidth: bubbleWidth - 24);
      detailPainter.paint(canvas, Offset(-bubbleWidth / 2 + 12, -bubbleHeight / 2 + 48));

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ArMarkerPainter oldDelegate) {
    if (oldDelegate.markers.length != markers.length) {
      return true;
    }
    for (int i = 0; i < markers.length; i++) {
      final _ArMarker a = markers[i];
      final _ArMarker b = oldDelegate.markers[i];
      if (a.zone.id != b.zone.id ||
          a.position != b.position ||
          a.scale != b.scale ||
          a.distance != b.distance) {
        return true;
      }
    }
    return false;
  }
}
