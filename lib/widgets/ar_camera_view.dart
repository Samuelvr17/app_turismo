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
        selectedCamera!,
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
    final List<DangerZone> filtered = widget.dangerZones.where((zone) {
      final double distance = _arService.calculateDistance(userLatLng, zone.center);
      return distance <= 1000;
    }).toList();

    filtered.sort((DangerZone a, DangerZone b) {
      final double distanceA = _arService.calculateDistance(userLatLng, a.center);
      final double distanceB = _arService.calculateDistance(userLatLng, b.center);
      return distanceA.compareTo(distanceB);
    });

    return filtered;
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
            color: Colors.black.withOpacity(0.65),
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

    final LatLng userLatLng = LatLng(userPosition.latitude, userPosition.longitude);
    final List<DangerZone> zones = _zonesWithinRadius();

    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.shield, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Zonas de peligro cercanas (${zones.length})',
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
            if (zones.isEmpty)
              const Text(
                'No hay zonas registradas a 1 km a la redonda.',
                style: TextStyle(color: Colors.white70),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * 0.45,
                ),
                child: ListView.builder(
                  itemCount: zones.length,
                  shrinkWrap: true,
                  itemBuilder: (BuildContext context, int index) {
                    final DangerZone zone = zones[index];
                    final double distance =
                        _arService.calculateDistance(userLatLng, zone.center);
                    final double bearing =
                        _arService.calculateBearing(userLatLng, zone.center);
                    final double relative = _relativeBearing(bearing);

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 10,
                            height: 52,
                            decoration: BoxDecoration(
                              color: _zoneColor(zone),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  zone.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    _InfoPill(
                                      icon: Icons.place,
                                      label: _formatDistance(distance),
                                    ),
                                    _InfoPill(
                                      icon: Icons.shield,
                                      label: switch (zone.level) {
                                        DangerLevel.high => 'Peligro alto',
                                        DangerLevel.medium => 'Peligro medio',
                                        DangerLevel.low => 'Peligro bajo',
                                      },
                                      color: _zoneColor(zone).withOpacity(0.8),
                                    ),
                                  ],
                                ),
                                if (zone.precautions.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      'Precauciones: ${zone.precautions}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                if (zone.securityRecommendations.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      'Recomendaciones: ${zone.securityRecommendations}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            children: [
                              Transform.rotate(
                                angle: relative * math.pi / 180,
                                child: Icon(
                                  Icons.navigation_rounded,
                                  color: _zoneColor(zone),
                                  size: 28,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${relative.toStringAsFixed(0)}°',
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

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color ?? Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
