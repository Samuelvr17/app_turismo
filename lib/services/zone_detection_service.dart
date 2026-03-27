import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/danger_zone.dart';
import 'local_storage_service.dart';
import 'supabase_service.dart';

class ZoneDetectionService {
  ZoneDetectionService({
    SupabaseService? supabase,
    LocalStorageService? localStorage,
  })  : _supabase = supabase ?? SupabaseService.instance,
        _localStorage = localStorage ?? LocalStorageService.instance;

  final SupabaseService _supabase;
  final LocalStorageService _localStorage;

  Future<List<DangerZone>> loadDangerZones() async {
    try {
      final List<DangerZone> zones = await _supabase.getDangerZonesWithPoints();
      
      // Cachear datos exitosos
      await _localStorage.cacheDangerZones(zones);
      
      return zones;
    } catch (e) {
      debugPrint('Error al cargar zonas de peligro desde Supabase: $e');
      
      // Fallback a cache local
      final List<DangerZone> cachedZones = await _localStorage.loadCachedDangerZones();
      return cachedZones;
    }
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