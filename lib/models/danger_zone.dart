import 'package:google_maps_flutter/google_maps_flutter.dart';

class DangerZone {
  const DangerZone({
    required this.id,
    required this.center,
    required this.name,
    required this.dangers,
    required this.precautions,
    required this.recommendations,
    this.radius = defaultRadius,
    this.altitude = defaultAltitude,
    this.overlayHeight = defaultOverlayHeight,
    this.summary,
  });

  static const double defaultRadius = 100;
  static const double defaultAltitude = 0;
  static const double defaultOverlayHeight = 20;

  final String id;
  final LatLng center;
  final String name;
  final List<String> dangers;
  final List<String> precautions;
  final List<String> recommendations;
  final double radius;
  final double altitude;
  final double overlayHeight;
  final String? summary;
}
