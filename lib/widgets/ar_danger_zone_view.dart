import 'dart:async';
import 'dart:math' as math;

import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

import '../models/danger_zone.dart';
import '../services/location_service.dart';
import '../services/permission_service.dart';

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

class _ArDangerZoneViewState extends State<ArDangerZoneView> {
  final LocationService _locationService = LocationService.instance;
  final PermissionService _permissionService = PermissionService.instance;
  late final VoidCallback _locationListener;

  ARSessionManager? _sessionManager;
  ARObjectManager? _objectManager;
  ARLocationManager? _locationManager;

  final Map<String, ARNode> _nodesByZoneId = <String, ARNode>{};

  Position? _latestPosition;
  Set<String> _highlightedZoneIds = <String>{};
  bool _isSessionReady = false;
  bool _cameraGranted = false;
  bool _isRequestingCamera = false;
  String? _errorMessage;

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

    _initializeCameraPermission();
  }

  @override
  void dispose() {
    _locationService.stateListenable.removeListener(_locationListener);
    unawaited(_clearNodes());
    unawaited(_sessionManager?.dispose());
    super.dispose();
  }

  Future<void> _initializeCameraPermission() async {
    if (_isRequestingCamera) {
      return;
    }

    _isRequestingCamera = true;
    final status = await _permissionService.requestCameraPermission();
    _isRequestingCamera = false;

    if (_permissionService.isPermissionGranted(status)) {
      setState(() {
        _cameraGranted = true;
        _errorMessage = null;
      });
    } else {
      final bool permanentlyDenied =
          _permissionService.isPermanentlyDenied(status);
      setState(() {
        _cameraGranted = false;
        _errorMessage = permanentlyDenied
            ? 'Habilita el permiso de cámara en la configuración del dispositivo para usar la vista AR.'
            : 'El permiso de cámara es necesario para mostrar la vista de realidad aumentada.';
      });
    }
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

    if ((_isSessionReady && (idsChanged || locationChanged || altitudeChanged))) {
      unawaited(_refreshNodes());
    }

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
    final Position? position = _latestPosition ?? widget.currentPosition;
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

  Future<void> _onARViewCreated(
    ARSessionManager sessionManager,
    ARObjectManager objectManager,
    ARAnchorManager anchorManager,
    ARLocationManager locationManager,
  ) async {
    _sessionManager = sessionManager;
    _objectManager = objectManager;
    _locationManager = locationManager;

    if (!_cameraGranted) {
      await _initializeCameraPermission();
      if (!_cameraGranted) {
        return;
      }
    }

    await _sessionManager?.onInitialize(
      showFeaturePoints: false,
      showPlanes: false,
      handlePans: true,
      handleRotation: true,
    );
    await _objectManager?.onInitialize();
    await _locationManager?.startLocationUpdates();
    _objectManager?.onNodeTap = _onNodeTap;

    _isSessionReady = true;
    await _refreshNodes();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refreshNodes() async {
    if (!_isSessionReady || _objectManager == null) {
      return;
    }

    await _clearNodes();
    final Position? reference = _latestPosition ?? widget.currentPosition;
    if (reference == null) {
      return;
    }

    final Iterable<DangerZone> zones = _zonesToDisplay();
    for (final zone in zones) {
      final double? rawDistance = _distanceToZone(zone);
      if (rawDistance == null) {
        continue;
      }
      final double bearing = Geolocator.bearingBetween(
        reference.latitude,
        reference.longitude,
        zone.center.latitude,
        zone.center.longitude,
      );
      final double distanceMeters = rawDistance.clamp(5, 150).toDouble();
      const double metersPerUnit = 10;
      final double scaledDistance =
          (distanceMeters / metersPerUnit).clamp(2, 35).toDouble();
      final double radians = bearing * math.pi / 180;

      final vector.Vector3 positionVector = vector.Vector3(
        scaledDistance * math.sin(radians),
        zone.overlayHeight,
        -scaledDistance * math.cos(radians),
      );

      final double scaleValue = _highlightedZoneIds.contains(zone.id) ? 0.9 : 0.6;
      final node = ARNode(
        type: NodeType.webGLB,
        uri:
            'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/Box/glTF-Binary/Box.glb',
        name: zone.id,
        position: positionVector,
        scale: vector.Vector3.all(scaleValue),
        data: <String, dynamic>{'zoneId': zone.id},
      );

      final bool? added = await _objectManager?.addNode(node);
      if (added == true) {
        _nodesByZoneId[zone.id] = node;
      }
    }
  }

  Future<void> _clearNodes() async {
    if (_objectManager == null) {
      return;
    }
    for (final node in _nodesByZoneId.values) {
      await _objectManager?.removeNode(node);
    }
    _nodesByZoneId.clear();
  }

  Future<void> _onNodeTap(List<String> nodeNames) async {
    if (nodeNames.isEmpty) {
      return;
    }
    final String tappedId = nodeNames.first;
    DangerZone? zone;
    for (final candidate in widget.dangerZones) {
      if (candidate.id == tappedId) {
        zone = candidate;
        break;
      }
    }
    if (zone == null || !mounted) {
      return;
    }
    await _showZoneInfo(zone);
  }

  Future<void> _showZoneInfo(DangerZone zone) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black.withValues(alpha: 0.8),
      builder: (BuildContext context) {
        final textTheme = Theme.of(context).textTheme;
        final double? distance = _distanceToZone(zone);
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            top: 16,
            left: 16,
            right: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      zone.title,
                      style: textTheme.titleMedium
                          ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (distance != null)
                    Text(
                      '${distance.toStringAsFixed(1)} m',
                      style: textTheme.bodySmall?.copyWith(color: Colors.white70),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                zone.description,
                style: textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              Text(
                'Peligros del área',
                style: textTheme.titleSmall
                    ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                zone.specificDangers,
                style: textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              Text(
                'Recomendaciones',
                style: textTheme.titleSmall
                    ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                zone.securityRecommendations,
                style: textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cerrar', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegend() {
    final Iterable<DangerZone> zones = _zonesToDisplay();
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Zonas de riesgo detectadas',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              for (final zone in zones) ...<Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _highlightedZoneIds.contains(zone.id)
                          ? Icons.location_on
                          : Icons.location_on_outlined,
                      size: 18,
                      color:
                          _highlightedZoneIds.contains(zone.id) ? Colors.redAccent : Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            zone.title,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            zone.description,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.white70),
                          ),
                          if (_distanceToZone(zone) != null)
                            Text(
                              'Distancia actual: ${_distanceToZone(zone)!.toStringAsFixed(1)} m',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.white70),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              if (zones.isEmpty)
                Text(
                  'No hay zonas de peligro activas en tu entorno inmediato.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white70),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArSurface() {
    if (!_cameraGranted) {
      return _buildErrorOverlay(
        _errorMessage ?? 'El permiso de cámara es necesario para activar la vista AR.',
        actionLabel: 'Conceder permiso',
        onAction: _initializeCameraPermission,
      );
    }

    return ARView(
      onARViewCreated: _onARViewCreated,
      planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
      showPlatformType: false,
      permissionPromptDescription:
          'La cámara es necesaria para superponer las zonas de peligro en tu entorno.',
      permissionPromptButtonText: 'Autorizar cámara',
      permissionPromptParentalRestriction:
          'El permiso de cámara está restringido por el sistema. Ajusta los controles parentales.',
    );
  }

  Widget _buildErrorOverlay(
    String message, {
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Theme.of(context).colorScheme.error, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zonas de peligro (AR)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => unawaited(_refreshNodes()),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: _buildArSurface()),
          _buildLegend(),
          if (_errorMessage != null && _cameraGranted)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                minimum: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
