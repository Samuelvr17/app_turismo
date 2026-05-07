import 'package:geolocator/geolocator.dart';

import 'danger_zone.dart';
import 'geo_point.dart';

/// Representa un punto específico de peligro perteneciente a una zona.
///
/// El [radius] define el radio de detección base en metros usado por la vista
/// AR. El overlay se activa al apuntar al punto cuando la distancia es menor
/// o igual al radio del punto o a 200 m (lo que sea mayor), permitiendo avisos
/// más tempranos para radios pequeños.
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
    this.level,
  });

  static const double defaultRadius = 30;

  final String id;
  final String dangerZoneId;
  final String title;
  final String description;
  final String precautions;
  final String recommendations;
  final GeoPoint location;
  final double radius;
  final DangerLevel? level;

  factory DangerZonePoint.fromJson(Map<String, dynamic> json) {
    final String? levelValue =
        (json['danger_level'] as String? ?? json['level'] as String?)
            ?.toLowerCase();
    
    final DangerLevel? level = levelValue == null ? null : switch (levelValue) {
      'alto riesgo' || 'alta' || 'high' => DangerLevel.high,
      'movimientos en masa o deslizamientos' || 'massmovement' => DangerLevel.massMovement,
      'puntos con asistencia o seguimiento técnico' || 'media' || 'medium' || 'monitored' => DangerLevel.monitored,
      'riesgo bajo' || 'baja' || 'low' => DangerLevel.low,
      _ => null,
    };

    return DangerZonePoint(
      id: json['id'].toString(),
      dangerZoneId: (json['danger_zone_id'] ?? json['dangerZoneId']).toString(),
      title: json['title'] as String? ?? 'Punto de peligro',
      description: json['description'] as String? ?? '',
      precautions: json['precautions'] as String? ?? '',
      recommendations: json['recommendations'] as String? ?? '',
      location: GeoPoint(
        (json['latitude'] as num?)?.toDouble() ?? 0,
        (json['longitude'] as num?)?.toDouble() ?? 0,
      ),
      radius: (json['radius'] as num?)?.toDouble() ?? defaultRadius,
      level: level,
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
      'danger_level': level != null ? _levelToString(level!) : null,
    };
  }

  static String _levelToString(DangerLevel level) {
    return switch (level) {
      DangerLevel.high => 'high',
      DangerLevel.massMovement => 'movimientos en masa o deslizamientos',
      DangerLevel.monitored => 'puntos con asistencia o seguimiento técnico',
      DangerLevel.low => 'low',
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
