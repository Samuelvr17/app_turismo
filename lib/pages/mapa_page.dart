import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/danger_zone.dart';
import '../services/location_service.dart';
import '../services/zone_detection_service.dart';
import '../widgets/ar_camera_view.dart';
import '../widgets/danger_zone_alert_dialog.dart';

class MapaPage extends StatefulWidget {
  const MapaPage({super.key});

  @override
  State<MapaPage> createState() => _MapaPageState();
}

class _MapaPageState extends State<MapaPage> {
  static const LatLng _defaultCameraTarget = LatLng(4.1162, -73.6088);
  final LocationService _locationService = LocationService.instance;
  final ZoneDetectionService _zoneDetectionService = ZoneDetectionService();
  late final VoidCallback _locationListener;
  List<DangerZone> _dangerZones = const <DangerZone>[];
  bool _zonesLoading = true;
  String? _zonesError;

  GoogleMapController? _mapController;
  Position? _currentPosition;
  Marker? _userMarker;
  bool _isLoading = true;
  String? _errorMessage;
  DangerZone? _activeZone;
  bool _isShowingDialog = false;

  @override
  void initState() {
    super.initState();
    _locationListener = () {
      _handleLocationUpdate(_locationService.state);
    };

    final LocationState initialState = _locationService.state;
    _isLoading = initialState.isLoading;
    _errorMessage = initialState.errorMessage;
    _currentPosition = initialState.position;
    _userMarker = initialState.position != null
        ? _buildUserMarker(initialState.position!)
        : null;

    final Position? initialPosition = initialState.position;
    if (initialPosition != null) {
      unawaited(_moveCameraToPosition(initialPosition));
    }

    _locationService.stateListenable.addListener(_locationListener);
    unawaited(_locationService.initialize());
    unawaited(_loadDangerZones());
  }

  @override
  void dispose() {
    _locationService.stateListenable.removeListener(_locationListener);
    _mapController?.dispose();
    super.dispose();
  }

  void _handleLocationUpdate(LocationState state) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = state.isLoading;
      _errorMessage = state.errorMessage;
      _currentPosition = state.position;
      _userMarker = state.position != null
          ? _buildUserMarker(state.position!)
          : null;
    });

    final Position? position = state.position;
    if (position != null) {
      unawaited(_moveCameraToPosition(position));
      if (_dangerZones.isNotEmpty) {
        unawaited(_evaluateDangerZones(position));
      }
    }
  }

  Future<void> _requestLocationRefresh() => _locationService.refresh();

  Future<void> _moveCameraToPosition(Position position) async {
    final controller = _mapController;
    if (controller == null) {
      return;
    }

    final target = LatLng(position.latitude, position.longitude);
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: 17),
      ),
    );
  }

  Future<void> _loadDangerZones() async {
    setState(() {
      _zonesLoading = true;
      _zonesError = null;
    });

    try {
      final List<DangerZone> zones = await _zoneDetectionService.loadDangerZones();
      if (!mounted) {
        return;
      }

      setState(() {
        _dangerZones = zones;
        _zonesLoading = false;
      });

      if (_currentPosition != null && _dangerZones.isNotEmpty) {
        unawaited(_evaluateDangerZones(_currentPosition!));
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _zonesError = 'No se pudieron cargar las zonas de peligro: $error';
        _zonesLoading = false;
      });
    }
  }

  Marker _buildUserMarker(Position position) {
    return Marker(
      markerId: const MarkerId('user_location'),
      position: LatLng(position.latitude, position.longitude),
      infoWindow: const InfoWindow(title: 'Tu ubicación'),
    );
  }

  Future<void> _evaluateDangerZones(Position position) async {
    final DangerZone? zone = _zoneDetectionService.findDangerZone(
      position: position,
      zones: _dangerZones,
      detectionRadius: 100,
    );

    if (zone == null) {
      if (_activeZone != null && mounted) {
        setState(() {
          _activeZone = null;
        });
      }
      return;
    }

    if (_activeZone?.id == zone.id || _isShowingDialog) {
      _activeZone = zone;
      return;
    }

    if (mounted) {
      setState(() {
        _activeZone = zone;
      });
    } else {
      _activeZone = zone;
    }

    await _showDangerDialog(zone);
  }

  Future<void> _openArDangerView({DangerZone? targetZone}) async {
    final Position? position = _currentPosition;
    if (position == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Activa la ubicación para abrir la vista de realidad aumentada.'),
        ),
      );
      return;
    }

    final PermissionStatus cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Se requiere permiso de cámara para la vista AR.'),
        ),
      );
      return;
    }

    final List<DangerZone> nearbyZones = _zoneDetectionService.collectNearbyZones(
      position: position,
      zones: _dangerZones,
      radiusInMeters: 1000,
    );

    if (targetZone != null && !nearbyZones.any((zone) => zone.id == targetZone.id)) {
      nearbyZones.add(targetZone);
    }

    if (nearbyZones.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay zonas cercanas para mostrar en AR.'),
          ),
        );
      }
      return;
    }

    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ArCameraView(
          dangerZones: nearbyZones,
          initialPosition: position,
        ),
      ),
    );
  }

  Future<void> _showDangerDialog(DangerZone zone) async {
    if (_isShowingDialog || !mounted) {
      return;
    }

    _isShowingDialog = true;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => DangerZoneAlertDialog(
          zone: zone,
          onDismiss: () => Navigator.of(dialogContext).pop(),
          onOpenAr: () {
            Navigator.of(dialogContext).pop();
            _openArDangerView(targetZone: zone);
          },
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isShowingDialog = false;
        });
      } else {
        _isShowingDialog = false;
      }
    }
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

  Set<Circle> get _dangerZoneCircles {
    return _dangerZones
        .map(
          (zone) => Circle(
            circleId: CircleId(zone.id),
            center: zone.center,
            radius: zone.radius,
            fillColor: _zoneColor(zone).withValues(alpha: 0.2),
            strokeColor: _zoneColor(zone).withValues(alpha: 0.5),
            strokeWidth: 2,
          ),
        )
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (_isLoading || _zonesLoading) {
      body = const Center(
        child: CircularProgressIndicator(),
      );
    } else if (_errorMessage != null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_off,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => unawaited(_requestLocationRefresh()),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    } else {
      final initialTarget = _currentPosition != null
          ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
          : (_dangerZones.isNotEmpty
              ? _dangerZones.first.center
              : _defaultCameraTarget);

      body = GoogleMap(
        initialCameraPosition: CameraPosition(target: initialTarget, zoom: 16),
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        compassEnabled: true,
        circles: _dangerZoneCircles,
        markers: {
          if (_userMarker != null) _userMarker!,
        },
        onMapCreated: (controller) {
          _mapController = controller;
          final position = _currentPosition;
          if (position != null) {
            _moveCameraToPosition(position);
          }
        },
      );
    }

    final bool canOpenAr = !_isLoading && _errorMessage == null && !_zonesLoading;

    return Stack(
      children: [
        Positioned.fill(child: body),
        if (_zonesError != null)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Material(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _zonesError!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (canOpenAr)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.extended(
              onPressed: _openArDangerView,
              icon: const Icon(Icons.view_in_ar),
              label: const Text('Ver en AR'),
            ),
          ),
      ],
    );
  }
}
