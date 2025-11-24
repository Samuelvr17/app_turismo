import 'dart:async';

import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/danger_zone.dart';
import '../services/ar_service.dart';
import '../widgets/ar_info_overlay.dart';

class ARDangerZoneScreen extends StatefulWidget {
  const ARDangerZoneScreen({
    super.key,
    required this.dangerZones,
    this.highlightedZoneIds = const <String>{},
    this.userPosition,
  });

  final List<DangerZone> dangerZones;
  final Set<String> highlightedZoneIds;
  final Position? userPosition;

  @override
  State<ARDangerZoneScreen> createState() => _ARDangerZoneScreenState();
}

class _ARDangerZoneScreenState extends State<ARDangerZoneScreen> {
  final ARService _arService = ARService.instance;

  bool _isCheckingSupport = true;
  bool _isArSupported = true;
  bool _sessionReady = false;

  List<DangerZone> get _zonesToDisplay {
    if (widget.highlightedZoneIds.isEmpty) {
      return widget.dangerZones;
    }

    return widget.dangerZones
        .where((zone) => widget.highlightedZoneIds.contains(zone.id))
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    final bool available = await _arService.isARAvailable();
    if (!mounted) {
      return;
    }

    setState(() {
      _isArSupported = available;
      _isCheckingSupport = false;
    });
  }

  Future<void> _onARViewCreated(
    ARSessionManager arSessionManager,
    ARObjectManager arObjectManager,
    ARAnchorManager arAnchorManager,
    ARLocationManager arLocationManager,
  ) async {
    await _arService.initAR(
      sessionManager: arSessionManager,
      objectManager: arObjectManager,
      anchorManager: arAnchorManager,
      locationManager: arLocationManager,
      showPlanes: true,
    );

    if (mounted) {
      setState(() {
        _sessionReady = true;
      });
    }
  }

  Widget _buildArBody() {
    if (_isCheckingSupport) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_isArSupported) {
      return _buildFallbackContainer(
        title: 'Cámara AR no disponible',
        message:
            'No pudimos acceder a la cámara o a los servicios de realidad aumentada. Revisa los permisos e intenta nuevamente.',
      );
    }

    return ARView(
      onARViewCreated: _onARViewCreated,
      planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
    );
  }

  Widget _buildFallbackContainer({required String title, required String message}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Colors.blueGrey.shade900,
            Colors.blueGrey.shade700,
            Colors.blueGrey.shade500,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.view_in_ar, size: 72, color: Colors.white.withOpacity(0.8)),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.white.withOpacity(0.85)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoPanel() {
    final List<DangerZone> zones = _zonesToDisplay;

    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        minimum: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (widget.userPosition != null) ...<Widget>[
                Text(
                  'Ubicación detectada',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.userPosition!.latitude.toStringAsFixed(5)}, ${widget.userPosition!.longitude.toStringAsFixed(5)}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 8),
              ],
              for (final DangerZone zone in zones) ArInfoOverlay(zone: zone),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCloseButton() {
    return Positioned(
      top: 12,
      right: 12,
      child: SafeArea(
        child: FloatingActionButton.small(
          heroTag: 'close_ar_view',
          backgroundColor: Colors.black.withOpacity(0.6),
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Icon(Icons.close, color: Colors.white),
        ),
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_arService.disposeAR());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          Positioned.fill(child: _buildArBody()),
          if (_sessionReady || !_isArSupported) _buildInfoPanel(),
          _buildCloseButton(),
        ],
      ),
    );
  }
}
