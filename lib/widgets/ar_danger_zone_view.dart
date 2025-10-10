import 'dart:async';

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
    super.dispose();
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
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue.shade900,
                  Colors.blue.shade700,
                  Colors.blue.shade500,
                ],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.camera_alt_outlined,
                    size: 80,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Vista AR no disponible',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'La funcionalidad de realidad aumentada está temporalmente deshabilitada. Puedes ver las zonas de peligro en el panel inferior.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildLegend(),
        ],
      ),
    );
  }
}
