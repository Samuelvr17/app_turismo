import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:permission_handler/permission_handler.dart';

class ARService {
  ARService._();

  static final ARService instance = ARService._();

  ARSessionManager? _sessionManager;
  ARObjectManager? _objectManager;
  ARAnchorManager? _anchorManager;
  ARLocationManager? _locationManager;

  bool get isInitialized => _sessionManager != null;

  Future<bool> isARAvailable() async {
    try {
      PermissionStatus status = await Permission.camera.status;
      if (!status.isGranted) {
        status = await Permission.camera.request();
      }
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  Future<void> initAR({
    required ARSessionManager sessionManager,
    required ARObjectManager objectManager,
    ARAnchorManager? anchorManager,
    ARLocationManager? locationManager,
    bool showFeaturePoints = false,
    bool showPlanes = true,
    bool showWorldOrigin = false,
  }) async {
    _sessionManager = sessionManager;
    _objectManager = objectManager;
    _anchorManager = anchorManager;
    _locationManager = locationManager;

    await _sessionManager?.onInitialize(
      showFeaturePoints: showFeaturePoints,
      showPlanes: showPlanes,
      showWorldOrigin: showWorldOrigin,
      handleTaps: false,
      handlePans: false,
      handleRotation: false,
    );

    await _objectManager?.onInitialize();
  }

  Future<void> disposeAR() async {
    await _objectManager?.dispose();
    await _sessionManager?.dispose();
    _sessionManager = null;
    _objectManager = null;
    _anchorManager = null;
    _locationManager = null;
  }
}
