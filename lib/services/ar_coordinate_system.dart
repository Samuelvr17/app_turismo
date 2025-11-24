import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

class ArMarkerProjection {
  ArMarkerProjection({
    required this.screenPosition,
    required this.distance,
    required this.scale,
  });

  final vm.Vector2 screenPosition;
  final double distance;
  final double scale;
}

class ArCoordinateSystem {
  static const double _earthSemiMajorAxis = 6378137.0; // meters
  static const double _earthFlattening = 1.0 / 298.257223563;

  static vm.Vector3 wgs84ToEcef({
    required double latitude,
    required double longitude,
    required double altitude,
  }) {
    final double latRad = vm.radians(latitude);
    final double lonRad = vm.radians(longitude);

    final double b = _earthSemiMajorAxis * (1 - _earthFlattening);
    final double eSquared = 1 - (b * b) / (_earthSemiMajorAxis * _earthSemiMajorAxis);
    final double sinLat = math.sin(latRad);
    final double cosLat = math.cos(latRad);
    final double sinLon = math.sin(lonRad);
    final double cosLon = math.cos(lonRad);

    final double n = _earthSemiMajorAxis / math.sqrt(1 - eSquared * sinLat * sinLat);

    final double x = (n + altitude) * cosLat * cosLon;
    final double y = (n + altitude) * cosLat * sinLon;
    final double z = ((b * b) / (_earthSemiMajorAxis * _earthSemiMajorAxis) * n + altitude) * sinLat;

    return vm.Vector3(x, y, z);
  }

  static vm.Vector3 enuFromReference({
    required Position reference,
    required Position target,
  }) {
    final vm.Vector3 refEcef = wgs84ToEcef(
      latitude: reference.latitude,
      longitude: reference.longitude,
      altitude: reference.altitude,
    );
    final vm.Vector3 targetEcef = wgs84ToEcef(
      latitude: target.latitude,
      longitude: target.longitude,
      altitude: target.altitude,
    );

    final vm.Vector3 delta = targetEcef - refEcef;

    final double latRad = vm.radians(reference.latitude);
    final double lonRad = vm.radians(reference.longitude);

    final double sinLat = math.sin(latRad);
    final double cosLat = math.cos(latRad);
    final double sinLon = math.sin(lonRad);
    final double cosLon = math.cos(lonRad);

    final vm.Vector3 east = vm.Vector3(-sinLon, cosLon, 0);
    final vm.Vector3 north = vm.Vector3(-sinLat * cosLon, -sinLat * sinLon, cosLat);
    final vm.Vector3 up = vm.Vector3(cosLat * cosLon, cosLat * sinLon, sinLat);

    final double e = east.dot(delta);
    final double n = north.dot(delta);
    final double u = up.dot(delta);

    return vm.Vector3(e, n, u);
  }

  static ArMarkerProjection? projectToScreen({
    required vm.Vector3 enuPosition,
    required double yaw,
    required double pitch,
    required double roll,
    required double horizontalFovDegrees,
    required double screenWidth,
    required double screenHeight,
  }) {
    if (screenWidth == 0 || screenHeight == 0) {
      return null;
    }

    // Rotate world (ENU) into camera space. Order: yaw -> pitch -> roll.
    final vm.Matrix3 yawMatrix = vm.Matrix3.rotationZ(-yaw);
    final vm.Matrix3 pitchMatrix = vm.Matrix3.rotationY(-pitch);
    final vm.Matrix3 rollMatrix = vm.Matrix3.rotationX(-roll);

    final vm.Matrix3 rotation = rollMatrix * (pitchMatrix * yawMatrix);
    final vm.Vector3 cameraSpace = rotation.transposed() * enuPosition;

    if (cameraSpace.z <= 0) {
      return null; // Behind the camera.
    }

    final double aspectRatio = screenWidth / screenHeight;
    final double horizontalFov = vm.radians(horizontalFovDegrees);
    final double verticalFov = 2 * math.atan(math.tan(horizontalFov / 2) / aspectRatio);

    final double xNdc = cameraSpace.x / (cameraSpace.z * math.tan(horizontalFov / 2));
    final double yNdc = cameraSpace.y / (cameraSpace.z * math.tan(verticalFov / 2));

    if (xNdc.abs() > 1 || yNdc.abs() > 1) {
      return null; // Outside field of view.
    }

    final double screenX = (xNdc * 0.5 + 0.5) * screenWidth;
    final double screenY = (1 - (yNdc * 0.5 + 0.5)) * screenHeight;

    final double distance = enuPosition.length;
    final double scale = _calculateScale(distance);

    return ArMarkerProjection(
      screenPosition: vm.Vector2(screenX, screenY),
      distance: distance,
      scale: scale,
    );
  }

  static double _calculateScale(double distanceMeters) {
    if (distanceMeters <= 0) {
      return 1.0;
    }
    final double base = 1 / (distanceMeters / 25 + 1);
    return base.clamp(0.35, 1.2);
  }
}
