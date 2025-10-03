import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/report.dart';
import '../models/safe_route.dart';
import '../models/user_preferences.dart';

class LocalStorageService {
  LocalStorageService._();

  static final LocalStorageService instance = LocalStorageService._();

  static const String _reportsBoxName = 'reports_box';
  static const String _preferencesKey = 'user_preferences';
  static const String _safeRoutesKey = 'safe_routes_cache';

  bool _isInitialized = false;
  SharedPreferences? _preferences;
  Box<Map<String, dynamic>>? _reportsBox;

  final ValueNotifier<List<Report>> _reportsNotifier =
      ValueNotifier<List<Report>>(<Report>[]);
  final ValueNotifier<UserPreferences> _preferencesNotifier =
      ValueNotifier<UserPreferences>(UserPreferences.defaults);

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    await Hive.initFlutter();
    _reportsBox = await Hive.openBox<Map<String, dynamic>>(_reportsBoxName);
    _preferences = await SharedPreferences.getInstance();

    await _loadStoredReports();
    await _loadStoredPreferences();

    _isInitialized = true;
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  Future<void> _loadStoredReports() async {
    final Box<Map<String, dynamic>>? box = _reportsBox;
    if (box == null) {
      return;
    }

    final List<Report> reports = box.values
        .map((Map<String, dynamic> raw) => Report.fromJson(raw))
        .toList(growable: false)
      ..sort(
        (Report a, Report b) => b.createdAt.compareTo(a.createdAt),
      );

    _reportsNotifier.value = reports;
  }

  Future<void> _loadStoredPreferences() async {
    final SharedPreferences? preferences = _preferences;
    if (preferences == null) {
      return;
    }

    final String? raw = preferences.getString(_preferencesKey);
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
    await _ensureInitialized();
    final Box<Map<String, dynamic>>? box = _reportsBox;
    if (box == null) {
      return;
    }

    await box.clear();
    for (final Report report in reports) {
      await box.put(report.id, report.toJson());
    }

    await _loadStoredReports();
  }

  Future<void> cacheReport(Report report) async {
    await _ensureInitialized();
    final Box<Map<String, dynamic>>? box = _reportsBox;
    if (box == null) {
      return;
    }

    await box.put(report.id, report.toJson());
    await _loadStoredReports();
  }

  Future<void> removeCachedReport(String id) async {
    await _ensureInitialized();
    final Box<Map<String, dynamic>>? box = _reportsBox;
    if (box == null) {
      return;
    }

    await box.delete(id);
    await _loadStoredReports();
  }

  Future<void> clearCachedReports() async {
    await _ensureInitialized();
    final Box<Map<String, dynamic>>? box = _reportsBox;
    if (box == null) {
      return;
    }

    await box.clear();
    await _loadStoredReports();
  }

  Future<void> cacheUserPreferences(UserPreferences preferences) async {
    await _ensureInitialized();
    final SharedPreferences? prefs = _preferences;
    if (prefs == null) {
      return;
    }

    final String encoded = json.encode(preferences.toJson());
    await prefs.setString(_preferencesKey, encoded);
    _preferencesNotifier.value = preferences;
  }

  Future<List<SafeRoute>> loadCachedSafeRoutes() async {
    await _ensureInitialized();
    final SharedPreferences? prefs = _preferences;
    if (prefs == null) {
      return <SafeRoute>[];
    }

    final String? raw = prefs.getString(_safeRoutesKey);
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
    await _ensureInitialized();
    final SharedPreferences? prefs = _preferences;
    if (prefs == null) {
      return;
    }

    final List<Map<String, dynamic>> serializedRoutes = routes
        .map((SafeRoute route) => route.toJson())
        .toList(growable: false);
    final String encoded = json.encode(serializedRoutes);
    await prefs.setString(_safeRoutesKey, encoded);
  }
}