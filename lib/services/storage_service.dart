import 'package:flutter/foundation.dart';

import '../models/report.dart';
import '../models/safe_route.dart';
import '../models/user_preferences.dart';
import 'local_storage_service.dart';
import 'supabase_service.dart';

class StorageService {
  StorageService._();

  static final StorageService instance = StorageService._();

  final LocalStorageService _localStorage = LocalStorageService.instance;
  final SupabaseService _supabase = SupabaseService.instance;

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    await _localStorage.initialize();

    await Future.wait<void>(<Future<void>>[
      _hydrateReportsFromSupabase(),
      _hydratePreferencesFromSupabase(),
      _hydrateSafeRoutesFromSupabase(),
    ]);

    _isInitialized = true;
  }

  Future<void> _hydrateReportsFromSupabase() async {
    try {
      final List<Report> supabaseReports = await _supabase.getReports();
      await _localStorage.cacheReports(supabaseReports);
    } catch (e) {
      debugPrint('Error al sincronizar reportes desde Supabase: $e');
    }
  }

  Future<void> _hydratePreferencesFromSupabase() async {
    try {
      final UserPreferences? preferences = await _supabase.getUserPreferences();
      if (preferences != null) {
        await _localStorage.cacheUserPreferences(preferences);
      }
    } catch (e) {
      debugPrint('Error al sincronizar preferencias desde Supabase: $e');
    }
  }

  Future<void> _hydrateSafeRoutesFromSupabase() async {
    try {
      final List<SafeRoute> routes = await _supabase.getSafeRoutes();
      await _localStorage.cacheSafeRoutes(routes);
    } catch (e) {
      debugPrint('Error al sincronizar rutas seguras desde Supabase: $e');
    }
  }

  ValueListenable<List<Report>> get reportsListenable =>
      _localStorage.reportsListenable;

  List<Report> get reports => _localStorage.reports;

  ValueListenable<UserPreferences> get preferencesListenable =>
      _localStorage.preferencesListenable;

  UserPreferences get preferences => _localStorage.preferences;

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  Future<Report> saveReport({
    required ReportType type,
    required String description,
    double? latitude,
    double? longitude,
  }) async {
    await _ensureInitialized();

    final Report report = await _supabase.saveReport(
      type: type,
      description: description,
      latitude: latitude,
      longitude: longitude,
    );

    await _localStorage.cacheReport(report);
    return report;
  }

  Future<void> deleteReport(String id) async {
    await _ensureInitialized();

    await _supabase.deleteReport(id);
    await _localStorage.removeCachedReport(id);
  }

  Future<void> clearReportsCache() async {
    await _ensureInitialized();
    await _localStorage.clearCachedReports();
  }

  Future<void> saveUserPreferences(UserPreferences preferences) async {
    await _ensureInitialized();

    await _supabase.saveUserPreferences(preferences);
    await _localStorage.cacheUserPreferences(preferences);
  }

  Future<List<SafeRoute>> loadSafeRoutes() async {
    await _ensureInitialized();

    try {
      final List<SafeRoute> routes = await _supabase.getSafeRoutes();
      await _localStorage.cacheSafeRoutes(routes);
      return routes;
    } catch (e) {
      debugPrint('Error al cargar rutas desde Supabase: $e');
    }

    return _localStorage.loadCachedSafeRoutes();
  }

  Future<void> saveSafeRoutes(List<SafeRoute> routes) async {
    await _ensureInitialized();

    await _supabase.saveSafeRoutes(routes);
    await _localStorage.cacheSafeRoutes(routes);
  }
}
