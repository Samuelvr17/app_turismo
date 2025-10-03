import 'package:flutter/foundation.dart';

import '../models/report.dart';
import '../models/safe_route.dart';
import '../models/user_preferences.dart';
import 'local_storage_service.dart';
import 'reports_remote_data_source.dart';
import 'supabase_service.dart';

class StorageService {
  StorageService({
    LocalStorageService? localStorage,
    ReportsRemoteDataSource? supabase,
  })  : _localStorage = localStorage ?? LocalStorageService.instance,
        _supabase = supabase ?? SupabaseService.instance;

  static final StorageService instance = StorageService();

  final LocalStorageService _localStorage;
  final ReportsRemoteDataSource _supabase;

  bool _baseInitialized = false;
  bool _isUserInitialized = false;
  String? _currentUserId;

  Future<void> initialize() async {
    if (_baseInitialized) {
      return;
    }

    await _localStorage.initialize();
    _baseInitialized = true;
  }

  Future<void> initializeForUser(String userId) async {
    await initialize();

    if (_isUserInitialized && _currentUserId == userId) {
      return;
    }

    _currentUserId = userId;
    await _localStorage.configureForUser(userId);

    await Future.wait<void>(<Future<void>>[
      _syncReportsFromSupabase(userId),
      _hydratePreferencesFromSupabase(userId),
      _hydrateSafeRoutesFromSupabase(userId),
    ]);

    _isUserInitialized = true;
  }

  Future<void> _syncReportsFromSupabase(String userId) async {
    try {
      final List<Report> supabaseReports =
          await _supabase.getReports(userId: userId);
      await _localStorage.clearCachedReports();
      for (final Report report in supabaseReports) {
        await _localStorage.saveReport(report: report);
      }
    } catch (e) {
      debugPrint('Error al sincronizar reportes desde Supabase: $e');
    }
  }

  @visibleForTesting
  Future<void> syncReportsFromSupabase() async {
    await _ensureUserInitialized();
    final String userId = _requiredUserId;
    await _syncReportsFromSupabase(userId);
  }

  Future<void> _hydratePreferencesFromSupabase(String userId) async {
    try {
      final UserPreferences? preferences =
          await _supabase.getUserPreferences(userId: userId);
      if (preferences != null) {
        await _localStorage.cacheUserPreferences(preferences);
      }
    } catch (e) {
      debugPrint('Error al sincronizar preferencias desde Supabase: $e');
    }
  }

  Future<void> _hydrateSafeRoutesFromSupabase(String userId) async {
    try {
      final List<SafeRoute> routes =
          await _supabase.getSafeRoutes(userId: userId);
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

  Future<void> _ensureUserInitialized() async {
    if (!_isUserInitialized) {
      throw StateError('No hay un usuario autenticado configurado.');
    }
  }

  Future<Report> saveReport({
    required ReportType type,
    required String description,
    double? latitude,
    double? longitude,
  }) async {
    await _ensureUserInitialized();

    final String userId = _requiredUserId;

    final Report report = await _supabase.saveReport(
      userId: userId,
      type: type,
      description: description,
      latitude: latitude,
      longitude: longitude,
    );

    await _localStorage.saveReport(report: report);
    return report;
  }

  Future<void> deleteReport(String id) async {
    await _ensureUserInitialized();

    final String userId = _requiredUserId;

    await _supabase.deleteReport(id: id, userId: userId);
    await _localStorage.removeCachedReport(id);
  }

  Future<void> clearReportsCache() async {
    await _ensureUserInitialized();
    await _localStorage.clearCachedReports();
  }

  Future<void> saveUserPreferences(UserPreferences preferences) async {
    await _ensureUserInitialized();

    final String userId = _requiredUserId;

    await _supabase.saveUserPreferences(
      userId: userId,
      preferences: preferences,
    );
    await _localStorage.cacheUserPreferences(preferences);
  }

  Future<List<SafeRoute>> loadSafeRoutes() async {
    await _ensureUserInitialized();

    final String userId = _requiredUserId;

    try {
      final List<SafeRoute> routes =
          await _supabase.getSafeRoutes(userId: userId);
      await _localStorage.cacheSafeRoutes(routes);
      return routes;
    } catch (e) {
      debugPrint('Error al cargar rutas desde Supabase: $e');
    }

    return _localStorage.loadCachedSafeRoutes();
  }

  Future<void> saveSafeRoutes(List<SafeRoute> routes) async {
    await _ensureUserInitialized();

    final String userId = _requiredUserId;

    await _supabase.saveSafeRoutes(userId: userId, routes: routes);
    await _localStorage.cacheSafeRoutes(routes);
  }

  Future<void> clearForSignOut() async {
    _isUserInitialized = false;
    _currentUserId = null;
    await _localStorage.clearForSignOut();
  }

  String get _requiredUserId {
    final String? userId = _currentUserId;
    if (userId == null) {
      throw StateError('No hay un usuario autenticado configurado.');
    }
    return userId;
  }
}
