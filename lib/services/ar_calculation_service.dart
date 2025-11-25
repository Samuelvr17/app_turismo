import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ArCalculationService {
  const ArCalculationService();

  double calculateDistance(LatLng origin, LatLng destination) {
    return Geolocator.distanceBetween(
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    );
  }

  double calculateBearing(LatLng origin, LatLng destination) {
    return Geolocator.bearingBetween(
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    );
  }

  bool isWithinFov(double targetBearing, double deviceHeading, {double fov = 60}) {
    final double normalized = _normalizeAngle(targetBearing - deviceHeading);
    return normalized.abs() <= fov / 2;
  }

  Offset? calculateScreenPosition({
    required LatLng userLocation,
    required LatLng targetLocation,
    required double heading,
    required double pitch,
    required Size screenSize,
    double horizontalFov = 60,
    double verticalFov = 60,
  }) {
    final double bearing = calculateBearing(userLocation, targetLocation);
    final double relativeBearing = _normalizeAngle(bearing - heading);

    if (relativeBearing.abs() > horizontalFov / 2) {
      return null;
    }

    final double xRatio = 0.5 - (relativeBearing / horizontalFov);
    final double clampedXRatio = xRatio.clamp(0, 1);

    final double pitchRatio = 0.5 - (pitch / verticalFov);
    final double clampedPitchRatio = pitchRatio.clamp(0, 1);

    final double x = clampedXRatio * screenSize.width;
    final double y = clampedPitchRatio * screenSize.height;

    return Offset(x, y);
  }

  double _normalizeAngle(double angle) {
    double normalized = angle % 360;
    if (normalized > 180) {
      normalized -= 360;
    } else if (normalized < -180) {
      normalized += 360;
    }
    return normalized;
  }
}
