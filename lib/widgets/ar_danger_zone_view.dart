import 'dart:async';

import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

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

  ARSessionManager? _arSessionManager;
  ARObjectManager? _arObjectManager;
  ARAnchorManager? _arAnchorManager;
  final Map<String, _ZoneAnchorData> _activeAnchors = <String, _ZoneAnchorData>{};
  bool _isArViewInitialized = false;

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

    final LocationState state = _locationService.state;
    if (!state.isLoading && state.position == null) {
      unawaited(_locationService.refresh());
    }
  }

  @override
  void dispose() {
    _locationService.stateListenable.removeListener(_locationListener);
    unawaited(_disposeArSession());
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ArDangerZoneView oldWidget) {
    super.didUpdateWidget(oldWidget);

    bool shouldUpdateAnchors = false;

    if (_setsDiffer(widget.activeZoneIds, oldWidget.activeZoneIds)) {
      if (widget.activeZoneIds.isNotEmpty) {
        _highlightedZoneIds = Set<String>.from(widget.activeZoneIds);
      } else if (_latestPosition != null) {
        _highlightedZoneIds = _resolveActiveZoneIds(_latestPosition!);
      } else {
        _highlightedZoneIds = <String>{};
      }
      shouldUpdateAnchors = true;
    }

    final Position? current = widget.currentPosition;
    final Position? previous = oldWidget.currentPosition;
    if (current != null && _positionsDiffer(current, previous)) {
      _latestPosition = current;
      if (_highlightedZoneIds.isEmpty) {
        _highlightedZoneIds = _resolveActiveZoneIds(current);
      }
      shouldUpdateAnchors = true;
    }

    if (shouldUpdateAnchors && mounted) {
      setState(() {});
      unawaited(_syncAnchors());
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

    if (idsChanged || altitudeChanged || locationChanged) {
      unawaited(_syncAnchors());
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

  bool _positionsDiffer(Position? current, Position? previous) {
    if (current == null && previous == null) {
      return false;
    }
    if (current == null || previous == null) {
      return true;
    }
    return current.latitude != previous.latitude ||
        current.longitude != previous.longitude ||
        current.altitude != previous.altitude;
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

  Widget _buildLegend() {
    final Iterable<DangerZone> zones = _zonesToDisplay();
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
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
                  zone.title,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: Colors.white, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zonas de peligro'),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: ARView(
              onARViewCreated: _onArViewCreated,
              planeDetectionConfig: PlaneDetectionConfig.none,
            ),
          ),
          _buildLegend(),
        ],
      ),
    );
  }

  Future<void> _onArViewCreated(
    ARSessionManager arSessionManager,
    ARObjectManager arObjectManager,
    ARAnchorManager arAnchorManager,
    ARLocationManager _,
  ) async {
    _arSessionManager = arSessionManager;
    _arObjectManager = arObjectManager;
    _arAnchorManager = arAnchorManager;

    try {
      await _arSessionManager?.onInitialize(
        showFeaturePoints: false,
        showPlanes: false,
        showWorldOrigin: false,
        handleTaps: false,
      );
      await _arObjectManager?.onInitialize();
    } catch (error, stackTrace) {
      debugPrint('No fue posible inicializar la sesión AR: $error');
      debugPrint(stackTrace.toString());
    }

    _isArViewInitialized = true;
    await _syncAnchors();
  }

  Future<void> _disposeArSession() async {
    final ARAnchorManager? anchorManager = _arAnchorManager;
    if (anchorManager != null) {
      final List<MapEntry<String, _ZoneAnchorData>> anchors =
          List<MapEntry<String, _ZoneAnchorData>>.from(_activeAnchors.entries);
      _activeAnchors.clear();
      for (final MapEntry<String, _ZoneAnchorData> entry in anchors) {
        try {
          await anchorManager.removeAnchor(entry.value.anchor);
        } catch (error) {
          debugPrint('No se pudo eliminar el ancla ${entry.key}: $error');
        }
      }
    }

    try {
      await _arSessionManager?.dispose();
    } catch (error) {
      debugPrint('Error al cerrar la sesión AR: $error');
    }
  }

  Future<void> _syncAnchors() async {
    if (!_isArViewInitialized) {
      return;
    }

    final ARAnchorManager? anchorManager = _arAnchorManager;
    if (anchorManager == null) {
      return;
    }

    final Iterable<DangerZone> zones = _zonesToDisplay();
    final Set<String> desiredIds = zones.map((DangerZone zone) => zone.id).toSet();

    final List<String> toRemove = _activeAnchors.keys
        .where((String id) => !desiredIds.contains(id))
        .toList(growable: false);

    for (final String id in toRemove) {
      final _ZoneAnchorData? data = _activeAnchors.remove(id);
      if (data == null) {
        continue;
      }
      try {
        await anchorManager.removeAnchor(data.anchor);
      } catch (error) {
        debugPrint('No se pudo eliminar el ancla $id: $error');
      }
    }

    for (final DangerZone zone in zones) {
      final double altitude = _resolveAltitudeForZone(zone);
      final _ZoneAnchorData? existing = _activeAnchors[zone.id];

      final bool needsUpdate = existing == null ||
          existing.latitude != zone.center.latitude ||
          existing.longitude != zone.center.longitude ||
          (existing.altitude - altitude).abs() > 0.5;

      if (!needsUpdate) {
        continue;
      }

      if (existing != null) {
        try {
          await anchorManager.removeAnchor(existing.anchor);
        } catch (error) {
          debugPrint('Error al reemplazar el ancla ${zone.id}: $error');
        }
      }

      final ARAnchor? anchor = await _createGeoAnchor(zone, altitude);
      if (anchor != null) {
        _activeAnchors[zone.id] = _ZoneAnchorData(
          anchor: anchor,
          latitude: zone.center.latitude,
          longitude: zone.center.longitude,
          altitude: altitude,
        );
      }
    }
  }

  Future<ARAnchor?> _createGeoAnchor(DangerZone zone, double altitude) async {
    final ARAnchorManager? anchorManager = _arAnchorManager;
    if (anchorManager == null) {
      return null;
    }

    final ARGeoAnchor anchor = ARGeoAnchor(
      latitude: zone.center.latitude,
      longitude: zone.center.longitude,
      altitude: altitude,
      name: zone.title,
    );

    try {
      final dynamic result = await anchorManager.addAnchor(anchor);
      if (result is ARAnchor) {
        return result;
      }
      if (result is bool) {
        return result ? anchor : null;
      }
      if (result != null) {
        return anchor;
      }
    } catch (error) {
      debugPrint('No se pudo crear el ancla para ${zone.id}: $error');
    }

    return null;
  }
}

class _ZoneAnchorData {
  const _ZoneAnchorData({
    required this.anchor,
    required this.latitude,
    required this.longitude,
    required this.altitude,
  });

  final ARAnchor anchor;
  final double latitude;
  final double longitude;
  final double altitude;
}
