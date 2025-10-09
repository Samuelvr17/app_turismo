import 'package:google_maps_flutter/google_maps_flutter.dart';

class DangerZone {
  const DangerZone({
    required this.id,
    required this.center,
    required this.title,
    required this.description,
    required this.specificDangers,
    required this.securityRecommendations,
    this.radius = defaultRadius,
    this.altitude = defaultAltitude,
    this.overlayHeight = defaultOverlayHeight,
  });

  static const double defaultRadius = 100;
  static const double defaultAltitude = 0;
  static const double defaultOverlayHeight = 20;

  final String id;
  final LatLng center;
  final String title;
  final String description;
  final String specificDangers;
  final String securityRecommendations;
  final double radius;
  final double altitude;
  final double overlayHeight;
}
