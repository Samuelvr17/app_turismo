import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
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
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isSyncing = false;

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
      _hydrateSafeRoutesFromSupabase(),
    ]);

    _isUserInitialized = true;
    _startConnectivityListener();
  }

  void _startConnectivityListener() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final bool hasConnection = results.any((result) => result != ConnectivityResult.none);
      if (hasConnection) {
        unawaited(syncPendingReports());
      }
    });
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

    Report? report;

    try {
      report = await _supabase.saveReport(
        userId: userId,
        type: type,
        description: description,
        latitude: latitude,
        longitude: longitude,
      );
      // report returns isSynced: true by default from Supabase
    } catch (e) {
      debugPrint('Error al guardar reporte en Supabase, guardando localmente: $e');
      // Crear reporte local temporal
      report = Report(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        typeId: type.id,
        description: description,
        createdAt: DateTime.now(),
        latitude: latitude,
        longitude: longitude,
        isSynced: false,
      );
    }

    await _localStorage.saveReport(report: report!);
    return report;
  }

  Future<void> syncPendingReports() async {
    if (_isSyncing || !_isUserInitialized) {
      return;
    }
    _isSyncing = true;

    try {
      final String userId = _currentUserId!;
      final List<Report> allReports = _localStorage.reports;
      final List<Report> pendingReports =
          allReports.where((Report r) => !r.isSynced).toList();

      if (pendingReports.isEmpty) {
        return;
      }

      debugPrint('Sincronizando ${pendingReports.length} reportes pendientes...');

      for (final Report pending in pendingReports) {
        try {
          final Report synced = await _supabase.saveReport(
            userId: userId,
            type: ReportType.fromId(pending.typeId),
            description: pending.description,
            latitude: pending.latitude,
            longitude: pending.longitude,
          );

          // Eliminar el local temporal y guardar el sincronizado
          await _localStorage.removeCachedReport(pending.id);
          await _localStorage.saveReport(report: synced);
        } catch (e) {
          debugPrint('No se pudo sincronizar reporte ${pending.id}: $e');
          // Continuar con el siguiente
        }
      }
    } finally {
      _isSyncing = false;
    }
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

    try {
      final List<SafeRoute> routes = await _supabase.getSafeRoutes();
      await _localStorage.cacheSafeRoutes(routes);
      return routes;
    } catch (e) {
      debugPrint('Error al cargar rutas desde Supabase: $e');
    }

    return _localStorage.loadCachedSafeRoutes();
  }

  Future<void> clearForSignOut() async {
    _isUserInitialized = false;
    _currentUserId = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
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
