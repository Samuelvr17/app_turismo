import 'package:google_maps_flutter/google_maps_flutter.dart';

class DangerZone {
  const DangerZone({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.dangers,
    required this.precautions,
    required this.recommendations,
    this.description,
    this.radius = defaultRadius,
    this.altitude = defaultAltitude,
    this.overlayHeight = defaultOverlayHeight,
  });

  static const double defaultRadius = 100;
  static const double defaultAltitude = 0;
  static const double defaultOverlayHeight = 20;

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final List<String> dangers;
  final List<String> precautions;
  final List<String> recommendations;
  final String? description;
  final double radius;
  final double altitude;
  final double overlayHeight;

  LatLng get center => LatLng(latitude, longitude);
}
