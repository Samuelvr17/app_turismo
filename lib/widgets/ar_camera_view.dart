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

  static const double _horizontalFov = 60;
  static const double _verticalFov = 60;

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

    final Size screenSize = Size(constraints.maxWidth, constraints.maxHeight);
    final List<_ZoneRenderData> renderData = zones.map((DangerZone zone) {
      final double distance =
          _arService.calculateDistance(userLatLng, zone.center);
      final double bearing =
          _arService.calculateBearing(userLatLng, zone.center);
      final double relative = _relativeBearing(bearing);
      final bool withinFov =
          _arService.isWithinFov(bearing, _heading, fov: _horizontalFov);

      final Offset? position = _arService.calculateScreenPosition(
        userLocation: userLatLng,
        targetLocation: zone.center,
        heading: _heading,
        pitch: _pitch,
        screenSize: screenSize,
        horizontalFov: _horizontalFov,
        verticalFov: _verticalFov,
      );

      final _EdgePosition edge = _calculateEdge(relative, _pitch);

      return _ZoneRenderData(
        zone: zone,
        distance: distance,
        bearing: bearing,
        relativeBearing: relative,
        screenPosition: position,
        isWithinFov: withinFov && position != null,
        edge: edge,
        color: _zoneColor(zone),
      );
    }).toList();

    final Map<_EdgePosition, List<_ZoneRenderData>> edgeGroups = {
      _EdgePosition.left: <_ZoneRenderData>[],
      _EdgePosition.right: <_ZoneRenderData>[],
      _EdgePosition.top: <_ZoneRenderData>[],
      _EdgePosition.bottom: <_ZoneRenderData>[],
    };

    for (final _ZoneRenderData data in renderData) {
      edgeGroups[data.edge]?.add(data);
    }

    final List<Widget> markerWidgets = renderData
        .where((data) => data.screenPosition != null)
        .map((data) => _buildMarker(data))
        .toList();

    final List<Widget> edgeWidgets = <Widget>[
      _buildEdgeIndicators(edgeGroups[_EdgePosition.left]!, _EdgePosition.left),
      _buildEdgeIndicators(edgeGroups[_EdgePosition.right]!, _EdgePosition.right),
      _buildEdgeIndicators(edgeGroups[_EdgePosition.top]!, _EdgePosition.top),
      _buildEdgeIndicators(edgeGroups[_EdgePosition.bottom]!, _EdgePosition.bottom),
    ];

    return Stack(
      children: [
        ...markerWidgets,
        ...edgeWidgets,
      ],
    );
  }

  _EdgePosition _calculateEdge(double relativeBearing, double pitch) {
    if (pitch > _verticalFov / 2) {
      return _EdgePosition.bottom;
    }
    if (pitch < -_verticalFov / 2) {
      return _EdgePosition.top;
    }
    return relativeBearing >= 0 ? _EdgePosition.right : _EdgePosition.left;
  }

  Widget _buildMarker(_ZoneRenderData data) {
    final Offset position = data.screenPosition ?? Offset.zero;
    final Color color = data.color;

    return Positioned(
      left: position.dx - 70,
      top: position.dy - 60,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        opacity: data.isWithinFov ? 1 : 0,
        child: IgnorePointer(
          ignoring: !data.isWithinFov,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withOpacity(0.7), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.4),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          data.zone.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDistance(data.distance),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEdgeIndicators(List<_ZoneRenderData> zones, _EdgePosition edge) {
    if (zones.isEmpty) {
      return const SizedBox.shrink();
    }

    final bool isHorizontal = edge == _EdgePosition.top || edge == _EdgePosition.bottom;
    final Widget indicators = isHorizontal
        ? Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: zones
                .map((data) => _EdgeIndicator(
                      data: data,
                      edge: edge,
                    ))
                .toList(),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: zones
                .map((data) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: _EdgeIndicator(
                        data: data,
                        edge: edge,
                      ),
                    ))
                .toList(),
          );

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: true,
        child: Align(
          alignment: switch (edge) {
            _EdgePosition.left => Alignment.centerLeft,
            _EdgePosition.right => Alignment.centerRight,
            _EdgePosition.top => Alignment.topCenter,
            _EdgePosition.bottom => Alignment.bottomCenter,
          },
          child: Padding(
            padding: EdgeInsets.only(
              left: edge == _EdgePosition.left ? 12 : 0,
              right: edge == _EdgePosition.right ? 12 : 0,
              top: edge == _EdgePosition.top ? 16 : 0,
              bottom: edge == _EdgePosition.bottom ? 16 : 24,
            ),
            child: indicators,
          ),
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

enum _EdgePosition { left, right, top, bottom }

class _ZoneRenderData {
  const _ZoneRenderData({
    required this.zone,
    required this.distance,
    required this.bearing,
    required this.relativeBearing,
    required this.screenPosition,
    required this.isWithinFov,
    required this.edge,
    required this.color,
  });

  final DangerZone zone;
  final double distance;
  final double bearing;
  final double relativeBearing;
  final Offset? screenPosition;
  final bool isWithinFov;
  final _EdgePosition edge;
  final Color color;
}

class _EdgeIndicator extends StatelessWidget {
  const _EdgeIndicator({required this.data, required this.edge});

  final _ZoneRenderData data;
  final _EdgePosition edge;

  @override
  Widget build(BuildContext context) {
    final IconData arrowIcon = switch (edge) {
      _EdgePosition.left => Icons.arrow_back_ios_new_rounded,
      _EdgePosition.right => Icons.arrow_forward_ios_rounded,
      _EdgePosition.top => Icons.arrow_upward_rounded,
      _EdgePosition.bottom => Icons.arrow_downward_rounded,
    };

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: data.isWithinFov ? 0 : 1,
      curve: Curves.easeInOut,
      child: Container(
        constraints: const BoxConstraints(minWidth: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.68),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: data.color.withOpacity(0.65), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: data.color.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(arrowIcon, color: data.color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${data.zone.title} | ${_formatDistanceStatic(data.distance)}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDistanceStatic(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }
}
