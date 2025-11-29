import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Servicio para cargar datos de rutas desde Supabase
/// 
/// Maneja la carga de ubicaciones de rutas e imágenes de actividades
/// con soporte para caché offline
class RouteDataService {
  RouteDataService._();
  static final RouteDataService instance = RouteDataService._();

  final SupabaseClient _supabase = Supabase.instance.client;

  // Caché en memoria
  Map<String, LatLng>? _cachedLocations;
  Map<String, Map<String, List<String>>>? _cachedImages;
  DateTime? _lastCacheUpdate;
  static const Duration _cacheExpiration = Duration(hours: 24);

  /// Obtiene las ubicaciones de todas las rutas
  /// 
  /// Retorna un Map con el nombre de la ruta como key y LatLng como value
  /// Usa caché si está disponible y no ha expirado
  Future<Map<String, LatLng>> getRouteLocations() async {
    // Verificar caché
    if (_cachedLocations != null && _isCacheValid()) {
      return _cachedLocations!;
    }

    try {
      final response = await _supabase
          .from('route_locations')
          .select('route_name, latitude, longitude');

      final Map<String, LatLng> locations = {};
      for (final item in response) {
        final String name = item['route_name'] as String;
        final double lat = (item['latitude'] as num).toDouble();
        final double lng = (item['longitude'] as num).toDouble();
        locations[name] = LatLng(lat, lng);
      }

      // Actualizar caché
      _cachedLocations = locations;
      _lastCacheUpdate = DateTime.now();

      return locations;
    } catch (error) {
      // Si falla y hay caché, usar caché aunque esté expirado
      if (_cachedLocations != null) {
        return _cachedLocations!;
      }
      
      // Si no hay caché, retornar mapa vacío
      return {};
    }
  }

  /// Obtiene las imágenes de una actividad específica
  /// 
  /// [routeName] - Nombre de la ruta
  /// [activityName] - Nombre de la actividad
  /// 
  /// Retorna una lista de URLs de imágenes ordenadas por display_order
  Future<List<String>> getActivityImages(
    String routeName,
    String activityName,
  ) async {
    try {
      final response = await _supabase
          .from('activity_images')
          .select('image_url')
          .eq('route_name', routeName)
          .eq('activity_name', activityName)
          .order('display_order');

      return response.map((e) => e['image_url'] as String).toList();
    } catch (error) {
      // Si falla, intentar obtener del caché completo
      if (_cachedImages != null) {
        return _cachedImages![routeName]?[activityName] ?? [];
      }
      return [];
    }
  }

  /// Obtiene todas las imágenes de actividades organizadas por ruta y actividad
  /// 
  /// Retorna un Map anidado: Map<ruteName, Map<activityName, List<imageUrl>>>
  /// Usa caché si está disponible y no ha expirado
  Future<Map<String, Map<String, List<String>>>> getAllActivityImages() async {
    // Verificar caché
    if (_cachedImages != null && _isCacheValid()) {
      return _cachedImages!;
    }

    try {
      final response = await _supabase
          .from('activity_images')
          .select('route_name, activity_name, image_url')
          .order('route_name')
          .order('activity_name')
          .order('display_order');

      final Map<String, Map<String, List<String>>> images = {};
      
      for (final item in response) {
        final String routeName = item['route_name'] as String;
        final String activityName = item['activity_name'] as String;
        final String imageUrl = item['image_url'] as String;

        images.putIfAbsent(routeName, () => {});
        images[routeName]!.putIfAbsent(activityName, () => []);
        images[routeName]![activityName]!.add(imageUrl);
      }

      // Actualizar caché
      _cachedImages = images;
      _lastCacheUpdate = DateTime.now();

      return images;
    } catch (error) {
      // Si falla y hay caché, usar caché aunque esté expirado
      if (_cachedImages != null) {
        return _cachedImages!;
      }
      
      // Si no hay caché, retornar mapa vacío
      return {};
    }
  }

  /// Verifica si el caché es válido (no ha expirado)
  bool _isCacheValid() {
    if (_lastCacheUpdate == null) {
      return false;
    }
    final Duration timeSinceUpdate = DateTime.now().difference(_lastCacheUpdate!);
    return timeSinceUpdate < _cacheExpiration;
  }

  /// Limpia el caché forzando una recarga en la próxima petición
  void clearCache() {
    _cachedLocations = null;
    _cachedImages = null;
    _lastCacheUpdate = null;
  }

  /// Precarga todos los datos en caché
  /// 
  /// Útil para llamar al inicio de la app para tener datos disponibles offline
  Future<void> preloadCache() async {
    await Future.wait([
      getRouteLocations(),
      getAllActivityImages(),
    ]);
  }
}
