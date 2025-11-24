import 'dart:async';
import 'dart:io';

import 'package:arcore_flutter_plugin/arcore_flutter_plugin.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

import '../models/danger_zone.dart';
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

class _ArDangerZoneViewState extends State<ArDangerZoneView> {
  final LocationService _locationService = LocationService.instance;
  late final VoidCallback _locationListener;

  ArCoreController? _arCoreController;
  bool _isCheckingSupport = true;
  bool _isSupported = false;
  String? _supportError;

  Position? _latestPosition;
  Set<String> _highlightedZoneIds = <String>{};

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

    unawaited(_checkArSupport());

    final LocationState state = _locationService.state;
    if (!state.isLoading && state.position == null) {
      unawaited(_locationService.refresh());
    }
  }

  @override
  void dispose() {
    _arCoreController?.dispose();
    _locationService.stateListenable.removeListener(_locationListener);
    super.dispose();
  }

  Future<void> _checkArSupport() async {
    try {
      final bool isAvailable = await ArCoreController.checkArCoreAvailability();
      final bool isInstalled = await ArCoreController.checkIsArCoreInstalled();

      if (!mounted) {
        return;
      }

      setState(() {
        _isSupported = isAvailable && isInstalled && Platform.isAndroid;
        _isCheckingSupport = false;
        _supportError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSupported = false;
        _isCheckingSupport = false;
        _supportError = 'Tu dispositivo no soporta ARCore o ocurrió un error al inicializarlo.';
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

  double _resolveAltitudeForZone(DangerZone zone) {
    if (zone.altitude != DangerZone.defaultAltitude) {
      return zone.altitude;
    }
    final Position? position = _latestPosition;
    if (position != null && position.altitude != 0) {
      return position.altitude + zone.overlayHeight;
    }
    return zone.overlayHeight;
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

  void _onArViewCreated(ArCoreController controller) {
    _arCoreController = controller;
    controller.onPlaneTap = _handleOnPlaneTap;
  }

  void _handleOnPlaneTap(List<ArCoreHitTestResult> hits) {
    if (hits.isEmpty || _arCoreController == null) {
      return;
    }

    final ArCoreHitTestResult hit = hits.first;
    _addWarningNodes(hit);
  }

  void _addWarningNodes(ArCoreHitTestResult hit) {
    final ArCoreController? controller = _arCoreController;
    if (controller == null) {
      return;
    }

    final Iterable<DangerZone> zones = _zonesToDisplay();
    final String title =
        zones.isNotEmpty ? zones.first.name : 'Zona peligrosa';

    final ArCoreMaterial warningMaterial =
        ArCoreMaterial(color: Colors.redAccent.withOpacity(0.9));

    final ArCoreNode sphereNode = ArCoreNode(
      shape: ArCoreSphere(radius: 0.12, materials: <ArCoreMaterial>[warningMaterial]),
      position: hit.pose.translation,
    );

    final ArCoreNode cubeNode = ArCoreNode(
      shape: ArCoreCube(
        materials: <ArCoreMaterial>[
          ArCoreMaterial(color: Colors.orangeAccent.withOpacity(0.85)),
        ],
        size: vector.Vector3.all(0.1),
      ),
      position: vector.Vector3(
        hit.pose.translation.x + 0.2,
        hit.pose.translation.y,
        hit.pose.translation.z,
      ),
      rotation: hit.pose.rotation,
    );

    final ArCoreNode textNode = ArCoreNode(
      text: ArCoreText(
        text: title,
        color: Colors.white,
        fontSize: 0.08,
      ),
      position: vector.Vector3(
        hit.pose.translation.x,
        hit.pose.translation.y + 0.25,
        hit.pose.translation.z,
      ),
      rotation: hit.pose.rotation,
    );

    controller.addArCoreNodeWithAnchor(sphereNode);
    controller.addArCoreNodeWithAnchor(cubeNode);
    controller.addArCoreNodeWithAnchor(textNode);
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
                Text(
                  zone.name,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  zone.description ?? 'No hay descripción disponible.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 6),
                Text(
                  'Peligros detectados',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white70, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                ...zone.dangers.map(
                  (danger) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: Colors.white70)),
                        Expanded(
                          child: Text(
                            danger,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Precauciones',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white70, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                ...zone.precautions.map(
                  (precaution) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: Colors.white70)),
                        Expanded(
                          child: Text(
                            precaution,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Recomendaciones',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white70, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                ...zone.recommendations.map(
                  (recommendation) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: Colors.white70)),
                        Expanded(
                          child: Text(
                            recommendation,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Radio: ${zone.radius.toStringAsFixed(0)} m | Altura virtual: ${_resolveAltitudeForZone(zone).toStringAsFixed(1)} m',
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

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (_isCheckingSupport) {
      body = const Center(child: CircularProgressIndicator());
    } else if (!_isSupported) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.view_in_ar, size: 64, color: Colors.orangeAccent),
              const SizedBox(height: 16),
              Text(
                'ARCore no está disponible en este dispositivo.',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              if (_supportError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _supportError!,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      );
    } else {
      body = Stack(
        children: [
          Positioned.fill(
            child: ArCoreView(
              onArCoreViewCreated: _onArViewCreated,
              enableTapRecognizer: true,
              enablePlaneRenderer: true,
            ),
          ),
          _buildLegend(),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zonas de peligro (AR)'),
      ),
      body: body,
    );
  }
}
