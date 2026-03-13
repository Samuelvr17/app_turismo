import 'dart:async';
import 'dart:math' as math;

import 'package:arcgis_maps/arcgis_maps.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/danger_zone.dart';
import '../models/geo_point.dart';
import '../services/location_service.dart';
import '../services/zone_detection_service.dart';
import '../widgets/ar_camera_view.dart';
import '../widgets/danger_zone_alert_dialog.dart';
import 'package:flutter_compass/flutter_compass.dart';

class MapaPage extends StatefulWidget {
  const MapaPage({super.key});

  @override
  State<MapaPage> createState() => _MapaPageState();
}

class _MapaPageState extends State<MapaPage> {
  static const GeoPoint _defaultCameraTarget = GeoPoint(4.1162, -73.6088);
  final LocationService _locationService = LocationService.instance;
  final ZoneDetectionService _zoneDetectionService = ZoneDetectionService();
  late final VoidCallback _locationListener;
  List<DangerZone> _dangerZones = const <DangerZone>[];
  bool _zonesLoading = true;
  String? _zonesError;

  final ArcGISMapViewController _mapViewController = ArcGISMapView.createController();
  Position? _currentPosition;
  double _heading = 0;
  StreamSubscription<CompassEvent>? _compassSubscription;
  bool _isLoading = true;
  String? _errorMessage;
  DangerZone? _activeZone;
  bool _isShowingDialog = false;

  late final ArcGISMap _arcGISMap;
  final GraphicsOverlay _userLocationOverlay = GraphicsOverlay();
  final GraphicsOverlay _dangerZonesOverlay = GraphicsOverlay();

  @override
  void initState() {
    super.initState();

    _arcGISMap = ArcGISMap.withBasemapStyle(BasemapStyle.arcGISNavigation);
    _arcGISMap.initialViewpoint = Viewpoint.withLatLongScale(
      latitude: _defaultCameraTarget.latitude,
      longitude: _defaultCameraTarget.longitude,
      scale: 10000,
    );
    _mapViewController.arcGISMap = _arcGISMap;

    _locationListener = () {
      _handleLocationUpdate(_locationService.state);
    };

    final LocationState initialState = _locationService.state;
    _isLoading = initialState.isLoading;
    _errorMessage = initialState.errorMessage;
    _currentPosition = initialState.position;

    _locationService.stateListenable.addListener(_locationListener);
    unawaited(_locationService.initialize());
    unawaited(_loadDangerZones());
    _startCompassUpdates();
  }

  @override
  void dispose() {
    _locationService.stateListenable.removeListener(_locationListener);
    _compassSubscription?.cancel();
    super.dispose();
  }

  void _onMapViewReady() {
    _mapViewController.graphicsOverlays.addAll([
      _dangerZonesOverlay,
      _userLocationOverlay,
    ]);

    final Position? position = _currentPosition;
    if (position != null) {
      _updateUserLocationGraphic(position);
      _moveCameraToPosition(position);
    }

    _updateDangerZoneGraphics();
  }

  void _handleLocationUpdate(LocationState state) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = state.isLoading;
      _errorMessage = state.errorMessage;
      _currentPosition = state.position;
    });

    final Position? position = state.position;
    if (position != null) {
      _updateUserLocationGraphic(position);
      _moveCameraToPosition(position);
      if (_dangerZones.isNotEmpty) {
        unawaited(_evaluateDangerZones(position));
      }
    }
  }

  void _updateUserLocationGraphic(Position position) {
    _userLocationOverlay.graphics.clear();

    final ArcGISPoint point = ArcGISPoint(
      x: position.longitude,
      y: position.latitude,
      spatialReference: SpatialReference.wgs84,
    );

    final SimpleMarkerSymbol symbol = SimpleMarkerSymbol(
      style: SimpleMarkerSymbolStyle.circle,
      color: Colors.blue,
      size: 14,
    );

    final SimpleMarkerSymbol outerSymbol = SimpleMarkerSymbol(
      style: SimpleMarkerSymbolStyle.circle,
      color: Colors.blue.withValues(alpha: 0.3),
      size: 28,
    );

    final SimpleMarkerSymbol directionSymbol = SimpleMarkerSymbol(
      style: SimpleMarkerSymbolStyle.triangle,
      color: Colors.white,
      size: 10,
    );
    directionSymbol.angle = _heading;

    _userLocationOverlay.graphics.addAll([
      Graphic(geometry: point, symbol: outerSymbol),
      Graphic(geometry: point, symbol: symbol),
      Graphic(geometry: point, symbol: directionSymbol),
    ]);
  }

  void _startCompassUpdates() {
    _compassSubscription = FlutterCompass.events?.listen((CompassEvent event) {
      final double? heading = event.heading;
      if (heading == null) {
        return;
      }

      if (mounted) {
        setState(() {
          _heading = heading;
        });

        // Solo actualizar el gráfico si ya tenemos una posición
        if (_currentPosition != null) {
          _updateUserLocationGraphic(_currentPosition!);
        }
      }
    });
  }

  void _updateDangerZoneGraphics() {
    _dangerZonesOverlay.graphics.clear();

    for (final DangerZone zone in _dangerZones) {
      final ArcGISPoint center = ArcGISPoint(
        x: zone.center.longitude,
        y: zone.center.latitude,
        spatialReference: SpatialReference.wgs84,
      );

      final Color zoneColor = _zoneColor(zone);

      final SimpleFillSymbol fillSymbol = SimpleFillSymbol(
        style: SimpleFillSymbolStyle.solid,
        color: zoneColor.withValues(alpha: 0.2),
        outline: SimpleLineSymbol(
          style: SimpleLineSymbolStyle.solid,
          color: zoneColor.withValues(alpha: 0.5),
          width: 2,
        ),
      );

      // Crear un polígono circular aproximado
      final Polygon circlePolygon = _createCirclePolygon(center, zone.radius);
      _dangerZonesOverlay.graphics.add(
        Graphic(geometry: circlePolygon, symbol: fillSymbol),
      );
    }
  }

  Polygon _createCirclePolygon(ArcGISPoint center, double radiusMeters) {
    final PolygonBuilder builder = PolygonBuilder(
      spatialReference: SpatialReference.wgs84,
    );

    const int numPoints = 64;


    for (int i = 0; i < numPoints; i++) {
      final double angle = (i * 360.0 / numPoints) * (math.pi / 180);
      // Approximate conversion from meters to degrees
      final double latOffset = (radiusMeters / 111320) * math.cos(angle);
      final double lonOffset =
          (radiusMeters / (111320 * math.cos(center.y * math.pi / 180))) *
              math.sin(angle);

      builder.addPoint(ArcGISPoint(
        x: center.x + lonOffset,
        y: center.y + latOffset,
        spatialReference: SpatialReference.wgs84,
      ));
    }

    return builder.toGeometry() as Polygon;
  }

  Future<void> _requestLocationRefresh() => _locationService.refresh();

  void _moveCameraToPosition(Position position) {
    final Viewpoint viewpoint = Viewpoint.withLatLongScale(
      latitude: position.latitude,
      longitude: position.longitude,
      scale: 5000,
    );
    _mapViewController.setViewpoint(viewpoint);
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

      _updateDangerZoneGraphics();

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
      case DangerLevel.massMovement:
        return Colors.orange;
      case DangerLevel.monitored:
        return Colors.yellow.shade700;
      case DangerLevel.low:
        return Colors.green;
    }
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
      body = ArcGISMapView(
        controllerProvider: () => _mapViewController,
        onMapViewReady: _onMapViewReady,
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
