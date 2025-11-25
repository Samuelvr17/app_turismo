import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../models/danger_zone.dart';
import '../models/danger_zone_point.dart';
import '../services/ar_calculation_service.dart';

class ArCameraView extends StatefulWidget {
  const ArCameraView({
    super.key,
    required this.dangerZones,
    required this.initialPosition,
  });

  final List<DangerZone> dangerZones;
  final Position initialPosition;

  @override
  State<ArCameraView> createState() => _ArCameraViewState();
}

class _ArCameraViewState extends State<ArCameraView> {
  final ArCalculationService _arService = const ArCalculationService();
  static const double _overlayMinDistanceMeters = 200;

  CameraController? _cameraController;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  Position? _userPosition;
  double _heading = 0;
  double _pitch = 0;
  bool _isCameraInitializing = true;
  String? _cameraError;
  DateTime _lastUiUpdate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _userPosition = widget.initialPosition;
    unawaited(_initializeCamera());
    _startPositionUpdates();
    _startCompassUpdates();
    _startAccelerometerUpdates();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _compassSubscription?.cancel();
    _accelerometerSubscription?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    final PermissionStatus status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() {
        _cameraError = 'Permiso de cámara denegado';
        _isCameraInitializing = false;
      });
      return;
    }

    try {
      final List<CameraDescription> cameras = await availableCameras();
      final CameraDescription selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.isNotEmpty ? cameras.first : throw StateError('No hay cámaras disponibles'),
      );

      final CameraController controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _isCameraInitializing = false;
      });
    } catch (error) {
      setState(() {
        _cameraError = 'No se pudo iniciar la cámara: $error';
        _isCameraInitializing = false;
      });
    }
  }

  void _startPositionUpdates() {
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    ).listen(
      (Position position) {
        _throttledSetState(() {
          _userPosition = position;
        });
      },
      onError: (Object error) {
        _throttledSetState(() {
          _cameraError = 'Sin acceso a ubicación: $error';
        });
      },
    );
  }

  void _startCompassUpdates() {
    _compassSubscription = FlutterCompass.events?.listen((CompassEvent event) {
      final double? heading = event.heading;
      if (heading == null) {
        return;
      }
      _throttledSetState(() {
        _heading = heading;
      });
    });
  }

  void _startAccelerometerUpdates() {
    _accelerometerSubscription = accelerometerEventStream().listen((AccelerometerEvent event) {
      final double pitchRadians = math.atan2(
        event.x,
        math.sqrt((event.y * event.y) + (event.z * event.z)),
      );
      final double pitchDegrees = pitchRadians * 180 / math.pi;

      _throttledSetState(() {
        _pitch = pitchDegrees.clamp(-90, 90);
      });
    });
  }

  void _throttledSetState(VoidCallback updater) {
    final DateTime now = DateTime.now();
    if (now.difference(_lastUiUpdate).inMilliseconds < 33) {
      return;
    }
    _lastUiUpdate = now;
    if (mounted) {
      setState(updater);
    }
  }

  List<_PointContext> _pointsWithinRadius({double radiusInMeters = 1200}) {
    final Position? userPosition = _userPosition;
    if (userPosition == null) {
      return const <_PointContext>[];
    }

    final LatLng userLatLng = LatLng(userPosition.latitude, userPosition.longitude);
    final List<_PointContext> contexts = <_PointContext>[];

    for (final DangerZone zone in widget.dangerZones) {
      for (final DangerZonePoint point in zone.points) {
        final double distance = _arService.calculateDistance(userLatLng, point.location);
        if (distance > radiusInMeters) {
          continue;
        }

        final double bearing = _arService.calculateBearing(userLatLng, point.location);
        contexts.add(
          _PointContext(
            zone: zone,
            point: point,
            distance: distance,
            relativeBearing: _relativeBearing(bearing),
          ),
        );
      }
    }

    contexts.sort(
      (_PointContext a, _PointContext b) => a.distance.compareTo(b.distance),
    );

    return contexts;
  }

  Color _zoneColor(DangerZone zone) {
    switch (zone.level) {
      case DangerLevel.high:
        return Colors.red;
      case DangerLevel.medium:
        return Colors.orange;
      case DangerLevel.low:
        return Colors.yellow.shade700;
    }
  }

  Widget _buildCameraBackground() {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      return CameraPreview(_cameraController!);
    }

    if (_isCameraInitializing) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          _cameraError ?? 'Cámara no disponible',
          style: const TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildStatusPanel() {
    final Position? position = _userPosition;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatusChip(label: 'Heading', value: '${_heading.toStringAsFixed(1)}°'),
                _StatusChip(label: 'Pitch', value: '${_pitch.toStringAsFixed(1)}°'),
                _StatusChip(
                  label: 'GPS',
                  value: position != null
                      ? '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}'
                      : 'Sin señal',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _relativeBearing(double bearing) {
    double normalized = (bearing - _heading) % 360;
    if (normalized > 180) {
      normalized -= 360;
    } else if (normalized < -180) {
      normalized += 360;
    }
    return normalized;
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }

  Widget _buildDangerOverlay(BoxConstraints constraints) {
    final Position? userPosition = _userPosition;
    if (userPosition == null) {
      return Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text(
            'Sin señal GPS. Activa la ubicación para ver las zonas de peligro cercanas.',
            style: TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final List<_PointContext> points = _pointsWithinRadius();
    // El overlay se activa para el punto más cercano dentro del FOV (±20°)
    // y a una distancia que sea al menos el radio configurado del punto o 200 m,
    // lo que sea mayor, para permitir avisos tempranos incluso con radios menores.
    final List<_PointContext> pointsInFov = points
        .where((context) {
          final double activationDistance =
              math.max(context.point.radius, _overlayMinDistanceMeters);
          return context.relativeBearing.abs() <= 20 &&
              context.distance <= activationDistance;
        })
        .toList()
      ..sort(
        (_PointContext a, _PointContext b) => a.distance.compareTo(b.distance),
      );
    final _PointContext? focusedPoint =
        pointsInFov.isNotEmpty ? pointsInFov.first : null;

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: focusedPoint != null
                  ? _FocusedPointOverlay(
                      key: ValueKey<String>(focusedPoint.point.id),
                      pointContext: focusedPoint,
                      distanceLabel: _formatDistance(focusedPoint.distance),
                      zoneColor: _zoneColor(focusedPoint.zone),
                      onViewZonePoints: () =>
                          _showZonePoints(focusedPoint.zone, userPosition),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.assistant_photo, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Puntos de peligro cercanos (${points.length})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _StatusChip(label: 'Heading', value: '${_heading.toStringAsFixed(0)}°'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (points.isEmpty)
                    const Text(
                      'No hay puntos registrados a 1.2 km a la redonda.',
                      style: TextStyle(color: Colors.white70),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: constraints.maxHeight * 0.45,
                      ),
                      child: ListView.builder(
                        itemCount: points.length,
                        shrinkWrap: true,
                        itemBuilder: (BuildContext context, int index) {
                          final _PointContext pointContext = points[index];

                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              children: [
                                Transform.rotate(
                                  angle: pointContext.relativeBearing * math.pi / 180,
                                  child: Icon(
                                    Icons.navigation_rounded,
                                    color: _zoneColor(pointContext.zone),
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${pointContext.point.title} | ${_formatDistance(pointContext.distance)}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        pointContext.zone.title,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${pointContext.relativeBearing.toStringAsFixed(0)}°',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      'Radio ${pointContext.point.radius.toStringAsFixed(0)} m',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showZonePoints(DangerZone zone, Position userPosition) async {
    if (!mounted) {
      return;
    }

    final LatLng userLatLng = LatLng(userPosition.latitude, userPosition.longitude);
    final List<_PointContext> zonePoints = zone.points
        .map(
          (DangerZonePoint point) => _PointContext(
            zone: zone,
            point: point,
            distance: _arService.calculateDistance(userLatLng, point.location),
            relativeBearing:
                _relativeBearing(_arService.calculateBearing(userLatLng, point.location)),
          ),
        )
        .toList()
      ..sort((_PointContext a, _PointContext b) => a.distance.compareTo(b.distance));

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.black.withValues(alpha: 0.9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Puntos en ${zone.title}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (zonePoints.isEmpty)
                  const Text(
                    'No hay puntos asociados a esta zona.',
                    style: TextStyle(color: Colors.white70),
                  )
                else
                  ...zonePoints.map(
                    (_PointContext pointData) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Transform.rotate(
                            angle: pointData.relativeBearing * math.pi / 180,
                            child: Icon(
                              Icons.navigation_rounded,
                              color: _zoneColor(zone),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pointData.point.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _formatDistance(pointData.distance),
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'Radio ${pointData.point.radius.toStringAsFixed(0)} m',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return Stack(
              children: [
                Positioned.fill(child: _buildCameraBackground()),
                Positioned.fill(child: _buildDangerOverlay(constraints)),
                _buildStatusPanel(),
                Positioned(
                  top: 12,
                  right: 12,
                  child: FloatingActionButton.small(
                    heroTag: 'close_ar_view',
                    backgroundColor: Colors.black54,
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _PointContext {
  const _PointContext({
    required this.zone,
    required this.point,
    required this.distance,
    required this.relativeBearing,
  });

  final DangerZone zone;
  final DangerZonePoint point;
  final double distance;
  final double relativeBearing;
}

class _FocusedPointOverlay extends StatelessWidget {
  const _FocusedPointOverlay({
    super.key,
    required this.pointContext,
    required this.distanceLabel,
    required this.zoneColor,
    required this.onViewZonePoints,
  });

  final _PointContext pointContext;
  final String distanceLabel;
  final Color zoneColor;
  final VoidCallback onViewZonePoints;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.place, color: zoneColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${pointContext.point.title} - ${pointContext.zone.title}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Distancia: $distanceLabel',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (pointContext.point.description.isNotEmpty)
            Text(
              pointContext.point.description,
              style: const TextStyle(color: Colors.white70),
            ),
          const SizedBox(height: 8),
          if (pointContext.point.precautions.isNotEmpty)
            Text(
              'Precauciones específicas: ${pointContext.point.precautions}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          if (pointContext.point.recommendations.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Recomendaciones: ${pointContext.point.recommendations}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          const SizedBox(height: 6),
          Text(
            'Zona: ${pointContext.zone.description}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Text(
            'Nivel: ${pointContext.zone.level.name.toUpperCase()} | Radio de detección ${pointContext.point.radius.toStringAsFixed(0)} m',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: onViewZonePoints,
              icon: const Icon(Icons.list_alt),
              label: Text('Ver otros puntos de ${pointContext.zone.title}'),
            ),
          ),
        ],
      ),
    );
  }
}