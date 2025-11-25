import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DangerZonePoint {
  const DangerZonePoint({
    required this.id,
    required this.dangerZoneId,
    required this.title,
    required this.description,
    required this.precautions,
    required this.recommendations,
    required this.location,
    this.radius = defaultRadius,
  });

  static const double defaultRadius = 30;

  final String id;
  final String dangerZoneId;
  final String title;
  final String description;
  final String precautions;
  final String recommendations;
  final LatLng location;
  final double radius;

  factory DangerZonePoint.fromJson(Map<String, dynamic> json) {
    return DangerZonePoint(
      id: json['id'].toString(),
      dangerZoneId: (json['danger_zone_id'] ?? json['dangerZoneId']).toString(),
      title: json['title'] as String? ?? 'Punto de peligro',
      description: json['description'] as String? ?? '',
      precautions: json['precautions'] as String? ?? '',
      recommendations: json['recommendations'] as String? ?? '',
      location: LatLng(
        (json['latitude'] as num?)?.toDouble() ?? 0,
        (json['longitude'] as num?)?.toDouble() ?? 0,
      ),
      radius: (json['radius'] as num?)?.toDouble() ?? defaultRadius,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'danger_zone_id': dangerZoneId,
      'title': title,
      'description': description,
      'precautions': precautions,
      'recommendations': recommendations,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'radius': radius,
    };
  }

  double distanceTo(Position position) {
    return Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      location.latitude,
      location.longitude,
    );
  }
}
