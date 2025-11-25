import 'package:geolocator/geolocator.dart';

import '../models/danger_zone.dart';
import 'supabase_service.dart';

class ZoneDetectionService {
  ZoneDetectionService({SupabaseService? supabase})
      : _supabase = supabase ?? SupabaseService.instance;

  final SupabaseService _supabase;

  Future<List<DangerZone>> loadDangerZones() async {
    return _supabase.getDangerZonesWithPoints();
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