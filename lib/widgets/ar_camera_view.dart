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
      final CameraDescription? selectedCamera = cameras.firstWhere(
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
    _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
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

  List<DangerZone> _zonesWithinRadius() {
    final Position? userPosition = _userPosition;
    if (userPosition == null) {
      return const <DangerZone>[];
    }
    final LatLng userLatLng = LatLng(userPosition.latitude, userPosition.longitude);
    return widget.dangerZones.where((zone) {
      final double distance = _arService.calculateDistance(userLatLng, zone.center);
      return distance <= 1000;
    }).toList();
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

  Widget _buildMarkers(BoxConstraints constraints) {
    final Position? userPosition = _userPosition;
    if (userPosition == null) {
      return const SizedBox.shrink();
    }

    final Size screenSize = Size(constraints.maxWidth, constraints.maxHeight);
    final LatLng userLatLng = LatLng(userPosition.latitude, userPosition.longitude);
    final List<Widget> markers = <Widget>[];

    for (final DangerZone zone in _zonesWithinRadius()) {
      final double bearing = _arService.calculateBearing(userLatLng, zone.center);
      if (!_arService.isWithinFov(bearing, _heading)) {
        continue;
      }

      final Offset? position = _arService.calculateScreenPosition(
        userLocation: userLatLng,
        targetLocation: zone.center,
        heading: _heading,
        pitch: _pitch,
        screenSize: screenSize,
      );

      if (position == null) {
        continue;
      }

      final double distance = _arService.calculateDistance(userLatLng, zone.center);

      markers.add(
        Positioned(
          left: position.dx - 24,
          top: position.dy - 24,
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _zoneColor(zone).withOpacity(0.8),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.shield, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      zone.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${distance.toStringAsFixed(0)} m',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(children: markers);
  }

  Widget _buildStatusPanel() {
    final Position? position = _userPosition;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return Stack(
              children: [
                Positioned.fill(child: _buildCameraBackground()),
                Positioned.fill(child: _buildMarkers(constraints)),
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
        color: Colors.white.withOpacity(0.1),
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
