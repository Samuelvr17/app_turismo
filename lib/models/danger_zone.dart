import 'danger_zone_point.dart';
import 'geo_point.dart';

enum DangerLevel { high, massMovement, monitored, low }

class DangerZone {
  const DangerZone({
    required this.id,
    required this.center,
    required this.title,
    required this.description,
    required this.specificDangers,
    required this.precautions,
    required this.securityRecommendations,
    required this.level,
    this.points = const <DangerZonePoint>[],
    this.radius = defaultRadius,
    this.altitude = defaultAltitude,
    this.overlayHeight = defaultOverlayHeight,
  });

  static const double defaultRadius = 100;
  static const double defaultAltitude = 0;
  static const double defaultOverlayHeight = 20;

  final String id;
  final GeoPoint center;
  final String title;
  final String description;
  final String specificDangers;
  final String precautions;
  final String securityRecommendations;
  final List<DangerZonePoint> points;
  final double radius;
  final double altitude;
  final double overlayHeight;
  final DangerLevel level;

  factory DangerZone.fromJson(Map<String, dynamic> json) {
    final String levelValue =
        (json['danger_level'] as String? ?? json['level'] as String? ?? '')
            .toLowerCase();
    final DangerLevel level = switch (levelValue) {
      'alto riesgo' || 'alta' || 'high' => DangerLevel.high,
      'movimientos en masa o deslizamientos' => DangerLevel.massMovement,
      'puntos con asistencia o seguimiento técnico' || 'media' || 'medium' => DangerLevel.monitored,
      'riesgo bajo' || 'baja' || 'low' => DangerLevel.low,
      _ => DangerLevel.low,
    };

    final double latitude = (json['latitude'] as num?)?.toDouble() ?? 0;
    final double longitude = (json['longitude'] as num?)?.toDouble() ?? 0;
    final List<dynamic> rawPoints =
        (json['points'] as List<dynamic>? ?? json['danger_zone_points'] as List<dynamic>? ?? <dynamic>[]);
    final List<DangerZonePoint> points = rawPoints
        .map((dynamic item) =>
            DangerZonePoint.fromJson(item as Map<String, dynamic>))
        .toList();

    return DangerZone(
      id: json['id'].toString(),
      center: GeoPoint(latitude, longitude),
      title: json['title'] as String? ?? json['name'] as String? ?? 'Zona',
      description: json['description'] as String? ?? 'Zona de peligro',
      specificDangers:
          json['specific_dangers'] as String? ?? json['details'] as String? ?? '',
      precautions: json['precautions'] as String? ?? 'Sigue las indicaciones locales.',
      securityRecommendations: json['security_recommendations'] as String? ??
          json['recommendations'] as String? ??
              'Permanece alerta y evita áreas sin iluminación.',
      level: level,
      points: points,
      radius: (json['radius'] as num?)?.toDouble() ?? defaultRadius,
      altitude: (json['altitude'] as num?)?.toDouble() ?? defaultAltitude,
      overlayHeight: (json['overlay_height'] as num?)?.toDouble() ?? defaultOverlayHeight,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'latitude': center.latitude,
      'longitude': center.longitude,
      'title': title,
      'description': description,
      'specific_dangers': specificDangers,
      'precautions': precautions,
      'security_recommendations': securityRecommendations,
      'danger_level': _levelToString(level),
      'points': points.map((p) => p.toJson()).toList(),
      'radius': radius,
      'altitude': altitude,
      'overlay_height': overlayHeight,
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
}
