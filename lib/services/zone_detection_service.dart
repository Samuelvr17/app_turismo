import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/danger_zone.dart';
import 'supabase_service.dart';

class ZoneDetectionService {
  ZoneDetectionService({SupabaseService? supabase})
      : _supabase = supabase ?? SupabaseService.instance;

  final SupabaseService _supabase;

  Future<List<DangerZone>> loadDangerZones() async {
    try {
      final response = await _supabase.client.from('danger_zones').select();

      if (response is List<dynamic> && response.isNotEmpty) {
        return response
            .map((item) => DangerZone.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // Se intenta recuperar desde la tabla reports si danger_zones no existe.
      try {
        final response = await _supabase.client
            .from('reports')
            .select('id, description, latitude, longitude, type_id');

        if (response is List<dynamic> && response.isNotEmpty) {
          return response
              .where((item) =>
                  (item['latitude'] as num?) != null &&
                  (item['longitude'] as num?) != null)
              .map(
                (item) => DangerZone(
                  id: item['id'].toString(),
                  center: LatLng(
                    (item['latitude'] as num).toDouble(),
                    (item['longitude'] as num).toDouble(),
                  ),
                  title: 'Reporte ${item['type_id'] ?? ''}',
                  description:
                      item['description'] as String? ?? 'Zona reportada por usuarios.',
                  specificDangers: 'Actividad sospechosa registrada.',
                  precautions:
                      'Evita permanecer en la zona y reporta cualquier novedad a las autoridades.',
                  securityRecommendations:
                      'Comparte tu ubicación con tus contactos de confianza.',
                  level: DangerLevel.medium,
                  radius: DangerZone.defaultRadius,
                  altitude: DangerZone.defaultAltitude,
                  overlayHeight: DangerZone.defaultOverlayHeight,
                ),
              )
              .toList();
        }
      } catch (_) {
        // Ignorado, se usará fallback local.
      }
    }

    return <DangerZone>[
      const DangerZone(
        id: 'fallback_1',
        center: LatLng(4.1162, -73.6088),
        title: 'Zona reportada',
        description: 'Área con reportes recientes de incidentes.',
        specificDangers: 'Robos a mano armada registrados.',
        precautions: 'Evita transitar solo y mantén tus pertenencias seguras.',
        securityRecommendations:
            'Reporta actividad sospechosa y utiliza rutas con buena iluminación.',
        level: DangerLevel.high,
        radius: 120,
      ),
    ];
  }

  DangerZone? findDangerZone({
    required Position position,
    required List<DangerZone> zones,
    double detectionRadius = 100,
  }) {
    for (final DangerZone zone in zones) {
      final double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        zone.center.latitude,
        zone.center.longitude,
      );

      if (distance <= detectionRadius && distance <= zone.radius) {
        return zone;
      }
    }
    return null;
  }

  List<DangerZone> collectNearbyZones({
    required Position position,
    required List<DangerZone> zones,
    double radiusInMeters = 1000,
  }) {
    return zones
        .where((zone) {
          final double distance = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            zone.center.latitude,
            zone.center.longitude,
          );
          return distance <= radiusInMeters;
        })
        .toList();
  }
}
