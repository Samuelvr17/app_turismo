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

  final ValueNotifier<List<Report>> _reportsNotifier =
      ValueNotifier<List<Report>>(<Report>[]);
  final ValueNotifier<UserPreferences> _preferencesNotifier =
      ValueNotifier<UserPreferences>(UserPreferences.defaults);

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    await _syncReportsFromSupabase();
    await _syncPreferencesFromSupabase();

    _localStorage.reportsListenable.addListener(() {
      _reportsNotifier.value = _localStorage.reports;
    });

    _localStorage.preferencesListenable.addListener(() {
      _preferencesNotifier.value = _localStorage.preferences;
    });

    _reportsNotifier.value = _localStorage.reports;
    _preferencesNotifier.value = _localStorage.preferences;

    _isInitialized = true;
  }

  Future<void> _syncReportsFromSupabase() async {
    try {
      final supabaseReports = await _supabase.getReports();

      for (final report in supabaseReports) {
        final reportType = ReportType.fromId(report.typeId);
        await _localStorage.saveReport(
          type: reportType,
          description: report.description,
          latitude: report.latitude,
          longitude: report.longitude,
        );
      }
    } catch (e) {
      debugPrint('Error al sincronizar reportes desde Supabase: $e');
    }
  }

  Future<void> _syncPreferencesFromSupabase() async {
    try {
      final preferences = await _supabase.getUserPreferences();
      if (preferences != null) {
        await _localStorage.saveUserPreferences(preferences);
      }
    } catch (e) {
      debugPrint('Error al sincronizar preferencias desde Supabase: $e');
    }
  }

  ValueListenable<List<Report>> get reportsListenable => _reportsNotifier;

  List<Report> get reports => _reportsNotifier.value;

  ValueListenable<UserPreferences> get preferencesListenable =>
      _preferencesNotifier;

  UserPreferences get preferences => _preferencesNotifier.value;

  Future<Report> saveReport({
    required ReportType type,
    required String description,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final report = await _supabase.saveReport(
        type: type,
        description: description,
        latitude: latitude,
        longitude: longitude,
      );

      await _localStorage.saveReport(
        type: type,
        description: description,
        latitude: latitude,
        longitude: longitude,
      );

      return report;
    } catch (e) {
      debugPrint('Error al guardar en Supabase, guardando solo localmente: $e');

      return await _localStorage.saveReport(
        type: type,
        description: description,
        latitude: latitude,
        longitude: longitude,
      );
    }
  }

  Future<void> deleteReport(String id) async {
    try {
      await _supabase.deleteReport(id);
    } catch (e) {
      debugPrint('Error al eliminar de Supabase: $e');
    }

    await _localStorage.deleteReport(id);
  }

  Future<void> clearReports() async {
    await _localStorage.clearReports();
  }

  Future<void> saveUserPreferences(UserPreferences preferences) async {
    try {
      await _supabase.saveUserPreferences(preferences);
    } catch (e) {
      debugPrint('Error al guardar preferencias en Supabase: $e');
    }

    await _localStorage.saveUserPreferences(preferences);
  }

  Future<List<SafeRoute>> loadSafeRoutes() async {
    try {
      final routes = await _supabase.getSafeRoutes();
      if (routes.isNotEmpty) {
        await _localStorage.saveSafeRoutes(routes);
        return routes;
      }
    } catch (e) {
      debugPrint('Error al cargar rutas desde Supabase: $e');
    }

    return await _localStorage.loadSafeRoutes();
  }

  Future<void> saveSafeRoutes(List<SafeRoute> routes) async {
    try {
      await _supabase.saveSafeRoutes(routes);
    } catch (e) {
      debugPrint('Error al guardar rutas en Supabase: $e');
    }

    await _localStorage.saveSafeRoutes(routes);
  }
}
