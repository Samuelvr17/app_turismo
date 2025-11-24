import 'dart:async';

import 'package:ar_flutter_plugin_updated/ar_flutter_plugin.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

import '../models/danger_zone.dart';
import '../services/ar_service.dart';

class ARDangerView extends StatefulWidget {
  const ARDangerView({
    super.key,
    required this.zone,
  });

  final DangerZone zone;

  @override
  State<ARDangerView> createState() => _ARDangerViewState();
}

class _ARDangerViewState extends State<ARDangerView> {
  ARSessionManager? _sessionManager;
  ARObjectManager? _objectManager;
  ARAnchorManager? _anchorManager;

  bool _isInitializing = true;
  bool _showTutorial = false;
  bool _anchorsReady = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTutorialFlag();
  }

  Future<void> _loadTutorialFlag() async {
    final bool shouldShow = await ARService.instance.shouldShowTutorial();
    if (!mounted) return;
    setState(() {
      _showTutorial = shouldShow;
    });
  }

  Future<void> _onARViewCreated(
    ARSessionManager sessionManager,
    ARObjectManager objectManager,
    ARAnchorManager anchorManager,
  ) async {
    _sessionManager = sessionManager;
    _objectManager = objectManager;
    _anchorManager = anchorManager;

    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      final ARSupportStatus supportStatus =
          await sessionManager.checkIfARSupported() ?? ARSupportStatus.notSupported;

      if (supportStatus == ARSupportStatus.notSupported) {
        setState(() {
          _errorMessage =
              'Tu dispositivo no soporta experiencias de realidad aumentada con ARCore.';
        });
        return;
      }

      await sessionManager.onInitialize(
        showFeaturePoints: false,
        showPlanes: true,
        showWorldOrigin: false,
        handleTaps: false,
      );

      await objectManager.onInitialize();
      await _placeDangerAnchors();

      setState(() {
        _anchorsReady = true;
      });
    } catch (error) {
      setState(() {
        _errorMessage = 'No se pudo iniciar la sesión AR: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _placeDangerAnchors() async {
    final vector.Matrix4 transform = vector.Matrix4.translationValues(0, 0, -1.5);

    final ARPlaneAnchor anchor = ARPlaneAnchor(
      transformation: transform.storage,
    );

    await _anchorManager?.addAnchor(anchor);
  }

  @override
  void dispose() {
    unawaited(_sessionManager?.dispose());
    super.dispose();
  }

  List<String> _asBulletList(String text) {
    final List<String> candidates =
        text.split(RegExp(r'[.;\n]')).map((String value) => value.trim()).toList();
    return candidates.where((String value) => value.isNotEmpty).toList();
  }

  Widget _buildDangerOverlay() {
    final List<String> precautions = _asBulletList(widget.zone.specificDangers);
    final List<String> recommendations = _asBulletList(widget.zone.securityRecommendations);

    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.6)),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Colors.black45,
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Zona detectada',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(color: Colors.orangeAccent),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.zone.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Precauciones',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (precautions.isEmpty)
                Text(
                  widget.zone.specificDangers,
                  style:
                      Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                )
              else
                ...precautions.map(
                  (String item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Padding(
                          padding: EdgeInsets.only(top: 3),
                          child: Icon(Icons.warning_amber, size: 18, color: Colors.amber),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                'Recomendaciones',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (recommendations.isEmpty)
                Text(
                  widget.zone.securityRecommendations,
                  style:
                      Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                )
              else
                ...recommendations.map(
                  (String item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Padding(
                          padding: EdgeInsets.only(top: 3),
                          child: Icon(Icons.check_circle, size: 18, color: Colors.greenAccent),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                'Mueve tu dispositivo para explorar y sigue las indicaciones visuales.',
                style:
                    Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTutorial() {
    if (!_showTutorial) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55)),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      'Bienvenido a la vista AR',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _showTutorial = false;
                        });
                        ARService.instance.markTutorialAsSeen();
                      },
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _tutorialStep('Busca una superficie plana para anclar indicadores de riesgo.'),
                _tutorialStep('Mueve tu dispositivo alrededor hasta que veas las guías flotantes.'),
                _tutorialStep('Toca "Cerrar" para volver al mapa en cualquier momento.'),
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _showTutorial = false;
                    });
                    ARService.instance.markTutorialAsSeen();
                  },
                  child: const Text('Entendido'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tutorialStep(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.check, color: Colors.greenAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicators() {
    if (_errorMessage != null) {
      return Positioned.fill(
        child: Container(
          color: Colors.black.withValues(alpha: 0.5),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.error_outline, color: Colors.white, size: 48),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style:
                    Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isInitializing) {
      return Positioned.fill(
        child: Container(
          color: Colors.black.withValues(alpha: 0.25),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const CircularProgressIndicator.adaptive(),
              const SizedBox(height: 12),
              Text(
                'Inicializando ARCore...',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    if (!_anchorsReady) {
      return Positioned(
        top: 24,
        left: 0,
        right: 0,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const <Widget>[
                Icon(Icons.sensors, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Buscando planos para colocar indicadores...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildFloatingIndicators() {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: true,
        child: AnimatedOpacity(
          opacity: _anchorsReady ? 1 : 0.4,
          duration: const Duration(milliseconds: 400),
          child: Stack(
            children: const <Widget>[
              _FloatingIndicator(
                alignment: Alignment.topRight,
                icon: Icons.emergency_share,
                label: 'Peligro cerca',
              ),
              _FloatingIndicator(
                alignment: Alignment.centerLeft,
                icon: Icons.my_location,
                label: 'Mantén atención',
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
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          ARView(onARViewCreated: _onARViewCreated),
          _buildStatusIndicators(),
          _buildFloatingIndicators(),
          _buildDangerOverlay(),
          _buildTutorial(),
        ],
      ),
    );
  }
}

class _FloatingIndicator extends StatelessWidget {
  const _FloatingIndicator({
    required this.alignment,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const <BoxShadow>[
              BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
