import 'dart:async';
import 'dart:math' as math;

import 'package:ar_flutter_plugin_engine/datatypes/node_types.dart';
import 'package:ar_flutter_plugin_engine/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_engine/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_engine/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_engine/models/ar_anchor.dart';
import 'package:ar_flutter_plugin_engine/models/ar_node.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vector_math/vector_math_64.dart';

import '../models/danger_zone.dart';

class ArDangerZoneOverlay extends StatefulWidget {
  const ArDangerZoneOverlay({
    super.key,
    required this.zone,
    required this.currentPosition,
    this.anchorManager,
    this.objectManager,
    this.sessionManager,
  });

  final DangerZone zone;
  final Position currentPosition;
  final ARAnchorManager? anchorManager;
  final ARObjectManager? objectManager;
  final ARSessionManager? sessionManager;

  @override
  State<ArDangerZoneOverlay> createState() => _ArDangerZoneOverlayState();
}

class _ArDangerZoneOverlayState extends State<ArDangerZoneOverlay> {
  ARPlaneAnchor? _radiusAnchor;
  ARNode? _radiusNode;
  bool _placingAnchor = false;

  @override
  void initState() {
    super.initState();
    unawaited(_syncAnchorWithScene());
  }

  @override
  void didUpdateWidget(covariant ArDangerZoneOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.anchorManager != widget.anchorManager ||
        oldWidget.objectManager != widget.objectManager ||
        oldWidget.zone.id != widget.zone.id) {
      unawaited(_syncAnchorWithScene());
    }
  }

  @override
  void dispose() {
    _removeAnchor();
    super.dispose();
  }

  Future<void> _syncAnchorWithScene() async {
    if (_placingAnchor) {
      return;
    }

    final ARAnchorManager? anchorManager = widget.anchorManager;
    final ARObjectManager? objectManager = widget.objectManager;
    final ARSessionManager? sessionManager = widget.sessionManager;

    if (anchorManager == null || objectManager == null || sessionManager == null) {
      return;
    }

    _placingAnchor = true;

    try {
      _removeAnchor();

      final Matrix4 transform = Matrix4.identity()..translate(0.0, 0.0, -1.5);
      final ARPlaneAnchor anchor = ARPlaneAnchor(
        transformation: transform,
        name: 'danger-${widget.zone.id}',
      );

      final bool? added = await anchorManager.addAnchor(anchor);
      if (added != true) {
        throw Exception('No se pudo crear el ancla AR.');
      }

      final double scale = (widget.zone.radius / 100).clamp(0.4, 3.0).toDouble();
      final ARNode node = ARNode(
        type: NodeType.webGLB,
        uri:
            'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/Torus/glTF-Binary/Torus.glb',
        scale: Vector3.all(scale),
        transformation: Matrix4.rotationX(-math.pi / 2),
      );

      final bool? addedNode = await objectManager.addNode(node, planeAnchor: anchor);
      if (addedNode == true) {
        _radiusAnchor = anchor;
        _radiusNode = node;
        await sessionManager.getDistanceFromAnchor(anchor);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo mostrar el indicador AR: $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      _placingAnchor = false;
    }
  }

  void _removeAnchor() {
    if (widget.objectManager != null && _radiusNode != null) {
      widget.objectManager!.removeNode(_radiusNode!);
      _radiusNode = null;
    }
    if (widget.anchorManager != null && _radiusAnchor != null) {
      widget.anchorManager!.removeAnchor(_radiusAnchor!);
      _radiusAnchor = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final DangerZone zone = widget.zone;
    final Position position = widget.currentPosition;

    final double distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      zone.center.latitude,
      zone.center.longitude,
    );
    final double proximity = (distance / zone.radius).clamp(0, 1).toDouble();

    final bool insideZone = distance <= zone.radius;

    return IgnorePointer(
      child: Align(
        alignment: Alignment.center,
        child: Container(
          width: 320,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.8)),
            boxShadow: const [
              BoxShadow(
                blurRadius: 12,
                color: Colors.black54,
                offset: Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          zone.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          zone.description,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _InfoRow(label: 'Peligros', value: zone.specificDangers),
              const SizedBox(height: 8),
              _InfoRow(label: 'Recomendaciones', value: zone.securityRecommendations),
              const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(
                    height: 80,
                    width: 80,
                    child: CustomPaint(
                      painter: _DangerRadiusPainter(progress: proximity),
                      child: Center(
                        child: Text(
                          '${distance.toStringAsFixed(0)} m',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          insideZone
                              ? 'Dentro del radio de peligro'
                              : 'A ${distance.toStringAsFixed(1)} m del centro',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(color: Colors.amberAccent, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Radio crítico: ${zone.radius.toStringAsFixed(0)} m · Altura AR: ${zone.overlayHeight.toStringAsFixed(1)} m',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.white.withValues(alpha: 0.8)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Panel fijo en el espacio AR para mantener la alerta visible.',
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
            ],
          ),
        ),
      ),
    );
  }
}

class _DangerRadiusPainter extends CustomPainter {
  _DangerRadiusPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = (size.shortestSide / 2) - 6;

    final Paint background = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final Paint foreground = Paint()
      ..color = Colors.amber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, background);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      foreground,
    );
  }

  @override
  bool shouldRepaint(covariant _DangerRadiusPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.amberAccent, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
        ),
      ],
    );
  }
}
