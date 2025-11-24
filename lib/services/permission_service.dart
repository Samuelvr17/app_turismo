import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  PermissionService._();

  static final PermissionService instance = PermissionService._();

  bool isPermissionGranted(PermissionStatus status) {
    return status.isGranted || status.isLimited || status == PermissionStatus.provisional;
  }

  bool isPermanentlyDenied(PermissionStatus status) => status.isPermanentlyDenied;

  Future<PermissionStatus> requestLocationWhenInUse() {
    return _requestPermission(Permission.locationWhenInUse);
  }

  Future<PermissionStatus> requestLocationAlways() async {
    final PermissionStatus whenInUseStatus = await requestLocationWhenInUse();
    if (!isPermissionGranted(whenInUseStatus)) {
      return whenInUseStatus;
    }
    return _requestPermission(Permission.locationAlways);
  }

  Future<PermissionStatus> requestCameraPermission() {
    return _requestPermission(Permission.camera);
  }

  Future<PermissionStatus> requestNotificationPermission() {
    return _requestPermission(Permission.notification);
  }

  Future<bool> openAppSettingsIfNeeded(PermissionStatus status) async {
    if (status.isPermanentlyDenied) {
      return openAppSettings();
    }
    return true;
  }

  Future<PermissionStatus> _requestPermission(Permission permission) async {
    final PermissionStatus currentStatus = await permission.status;
    if (_shouldRequest(currentStatus)) {
      return permission.request();
    }
    return currentStatus;
  }

  bool _shouldRequest(PermissionStatus status) {
    return status.isDenied || status.isRestricted || status.isLimited;
  }
}
