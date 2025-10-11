import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/report.dart';
import '../models/safe_route.dart';
import '../models/user_preferences.dart';

class LocalStorageService {
  LocalStorageService._();

  static final LocalStorageService instance = LocalStorageService._();

  static const String _reportsBoxNamePrefix = 'reports_box';
  static const String _preferencesKey = 'user_preferences';
  static const String _safeRoutesKey = 'safe_routes_cache';

  bool _baseInitialized = false;
  String? _currentUserId;
  SharedPreferences? _preferences;
  Box<dynamic>? _reportsBox;

  final ValueNotifier<List<Report>> _reportsNotifier =
      ValueNotifier<List<Report>>(<Report>[]);
  final ValueNotifier<UserPreferences> _preferencesNotifier =
      ValueNotifier<UserPreferences>(UserPreferences.defaults);

  Future<void> initialize() async {
    if (_baseInitialized) {
      return;
    }

    await Hive.initFlutter();
    _preferences = await SharedPreferences.getInstance();
    _baseInitialized = true;
  }

  Future<void> configureForUser(String userId) async {
    await initialize();

    if (_currentUserId == userId && _reportsBox != null) {
      await _loadStoredReports();
      await _loadStoredPreferences();
      return;
    }

    _currentUserId = userId;
    await _reportsBox?.close();
    _reportsBox = await Hive.openBox<dynamic>(
      _reportsBoxNameForUser(userId),
    );

    await _loadStoredReports();
    await _loadStoredPreferences();
  }

  Future<void> _loadStoredReports() async {
    final Box<dynamic>? box = _reportsBox;
    if (box == null) {
      return;
    }

    final List<Report> reports = <Report>[];

    for (final dynamic key in box.keys) {
      final dynamic raw = box.get(key);
      if (raw == null) {
        continue;
      }

      try {
        final Map<String, dynamic> serialized =
            Map<String, dynamic>.from(raw as Map<dynamic, dynamic>);
        reports.add(Report.fromJson(serialized));
      } on FormatException catch (error, stackTrace) {
        debugPrint('Error al cargar reporte "$key": $error');
        debugPrint('$stackTrace');
        await box.delete(key);
      } on TypeError catch (error, stackTrace) {
        debugPrint('Error al cargar reporte "$key": $error');
        debugPrint('$stackTrace');
        await box.delete(key);
      }
    }

    reports.sort(
      (Report a, Report b) => b.createdAt.compareTo(a.createdAt),
    );

    _reportsNotifier.value = reports;
  }

  Future<void> _loadStoredPreferences() async {
    final SharedPreferences? preferences = _preferences;
    final String? userId = _currentUserId;
    if (preferences == null || userId == null) {
      return;
    }

    final String? raw =
        preferences.getString(_preferencesStorageKey(userId));
    if (raw == null || raw.isEmpty) {
      _preferencesNotifier.value = UserPreferences.defaults;
      return;
    }

    try {
      final Map<String, dynamic> decoded =
          Map<String, dynamic>.from(json.decode(raw) as Map<dynamic, dynamic>);
      _preferencesNotifier.value = UserPreferences.fromJson(decoded);
    } on FormatException {
      _preferencesNotifier.value = UserPreferences.defaults;
    } on TypeError {
      _preferencesNotifier.value = UserPreferences.defaults;
    }
  }

  ValueListenable<List<Report>> get reportsListenable => _reportsNotifier;

  List<Report> get reports => List<Report>.unmodifiable(_reportsNotifier.value);

  ValueListenable<UserPreferences> get preferencesListenable => _preferencesNotifier;

  UserPreferences get preferences => _preferencesNotifier.value;

  Future<void> cacheReports(List<Report> reports) async {
    await _ensureConfigured();
    final Box<dynamic>? box = _reportsBox;
    if (box == null) {
      return;
    }

    await box.clear();
    for (final Report report in reports) {
      await box.put(report.id, report.toJson());
    }

    await _loadStoredReports();
  }

  Future<Report> saveReport({
    Report? report,
    ReportType? type,
    String? description,
    double? latitude,
    double? longitude,
    String? id,
    DateTime? createdAt,
  }) async {
    await _ensureConfigured();
    final Box<dynamic>? box = _reportsBox;
    if (box == null) {
      throw StateError('Reports box is not initialized');
    }

    Report reportToSave;
    if (report != null) {
      reportToSave = report;
    } else {
      if (type == null) {
        throw ArgumentError(
          'type is required when report is not provided',
        );
      }
      if (description == null) {
        throw ArgumentError(
          'description is required when report is not provided',
        );
      }

      final String resolvedId = id ??
          DateTime.now().microsecondsSinceEpoch.toString();
      final DateTime resolvedCreatedAt = createdAt ?? DateTime.now();

      reportToSave = Report(
        id: resolvedId,
        typeId: type.id,
        description: description,
        createdAt: resolvedCreatedAt,
        latitude: latitude,
        longitude: longitude,
      );
    }

    await box.put(reportToSave.id, reportToSave.toJson());
    await _loadStoredReports();
    return reportToSave;
  }

  Future<void> cacheReport(Report report) async {
    await _ensureConfigured();
    final Box<dynamic>? box = _reportsBox;
    if (box == null) {
      return;
    }

    await box.put(report.id, report.toJson());
    await _loadStoredReports();
  }

  Future<void> removeCachedReport(String id) async {
    await _ensureConfigured();
    final Box<dynamic>? box = _reportsBox;
    if (box == null) {
      return;
    }

    await box.delete(id);
    await _loadStoredReports();
  }

  Future<void> clearCachedReports() async {
    await _ensureConfigured();
    final Box<dynamic>? box = _reportsBox;
    if (box == null) {
      return;
    }

    await box.clear();
    await _loadStoredReports();
  }

  Future<void> cacheUserPreferences(UserPreferences preferences) async {
    await _ensureConfigured();
    final SharedPreferences? prefs = _preferences;
    final String? userId = _currentUserId;
    if (prefs == null || userId == null) {
      return;
    }

    final String encoded = json.encode(preferences.toJson());
    await prefs.setString(_preferencesStorageKey(userId), encoded);
    _preferencesNotifier.value = preferences;
  }

  Future<List<SafeRoute>> loadCachedSafeRoutes() async {
    await _ensureConfigured();
    final SharedPreferences? prefs = _preferences;
    final String? userId = _currentUserId;
    if (prefs == null || userId == null) {
      return <SafeRoute>[];
    }

    final String? raw = prefs.getString(_safeRoutesStorageKey(userId));
    if (raw == null || raw.isEmpty) {
      return <SafeRoute>[];
    }

    try {
      final List<dynamic> decoded = json.decode(raw) as List<dynamic>;
      return decoded
          .map(
            (dynamic item) => SafeRoute.fromJson(
              Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
            ),
          )
          .toList(growable: false);
    } on FormatException {
      return <SafeRoute>[];
    } on TypeError {
      return <SafeRoute>[];
    }
  }

  Future<void> cacheSafeRoutes(List<SafeRoute> routes) async {
    await _ensureConfigured();
    final SharedPreferences? prefs = _preferences;
    final String? userId = _currentUserId;
    if (prefs == null || userId == null) {
      return;
    }

    final List<Map<String, dynamic>> serializedRoutes = routes
        .map((SafeRoute route) => route.toJson())
        .toList(growable: false);
    final String encoded = json.encode(serializedRoutes);
    await prefs.setString(_safeRoutesStorageKey(userId), encoded);
  }

  Future<void> clearForSignOut() async {
    await _reportsBox?.close();
    _reportsBox = null;
    _currentUserId = null;
    _reportsNotifier.value = <Report>[];
    _preferencesNotifier.value = UserPreferences.defaults;
  }

  Future<void> _ensureConfigured() async {
    if (!_baseInitialized) {
      await initialize();
    }
    if (_currentUserId == null) {
      throw StateError('No hay un usuario autenticado configurado.');
    }
  }

  String _reportsBoxNameForUser(String userId) =>
      '${_reportsBoxNamePrefix}_$userId';

  String _preferencesStorageKey(String userId) => '${userId}_$_preferencesKey';

  String _safeRoutesStorageKey(String userId) => '${userId}_$_safeRoutesKey';
}