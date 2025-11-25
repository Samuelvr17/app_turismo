import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/danger_zone.dart';
import 'supabase_service.dart';

class ZoneDetectionService {
  ZoneDetectionService({SupabaseService? supabase})
      : _supabase = supabase ?? SupabaseService.instance;

  final SupabaseService _supabase;

  Future<List<DangerZone>> loadDangerZones() async {
    final response = await _supabase.client
        .from('danger_zones')
        .select()
        .order('updated_at', ascending: false);

    if (response is! List<dynamic> || response.isEmpty) {
      return const <DangerZone>[];
    }

    return response
        .map((item) => DangerZone.fromJson(item as Map<String, dynamic>))
        .toList();
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
