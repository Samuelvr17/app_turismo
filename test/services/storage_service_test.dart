import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:app_turismo/models/report.dart';
import 'package:app_turismo/models/safe_route.dart';
import 'package:app_turismo/models/user_preferences.dart';
import 'package:app_turismo/services/local_storage_service.dart';
import 'package:app_turismo/services/reports_remote_data_source.dart';
import 'package:app_turismo/services/storage_service.dart';

class _FakeSupabaseService implements ReportsRemoteDataSource {
  _FakeSupabaseService({List<Report>? reports})
      : _reports = List<Report>.from(reports ?? <Report>[]);

  List<Report> _reports;
  UserPreferences? _preferences;
  List<SafeRoute> _routes = <SafeRoute>[];

  void setReports(List<Report> reports) {
    _reports = List<Report>.from(reports);
  }

  @override
  Future<void> deleteReport({
    required String id,
    required String userId,
  }) async {
    _reports.removeWhere((Report report) => report.id == id);
  }

  @override
  Future<List<Report>> getReports({required String userId}) async {
    return List<Report>.from(_reports);
  }

  @override
  Future<List<SafeRoute>> getSafeRoutes({required String userId}) async {
    return List<SafeRoute>.from(_routes);
  }

  @override
  Future<UserPreferences?> getUserPreferences({required String userId}) async {
    return _preferences;
  }

  @override
  Future<Report> saveReport({
    required String userId,
    required ReportType type,
    required String description,
    double? latitude,
    double? longitude,
  }) async {
    final Report report = Report(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      typeId: type.id,
      description: description,
      createdAt: DateTime.now(),
      latitude: latitude,
      longitude: longitude,
    );
    _reports.insert(0, report);
    return report;
  }

  @override
  Future<void> saveSafeRoutes({
    required String userId,
    required List<SafeRoute> routes,
  }) async {
    _routes = List<SafeRoute>.from(routes);
  }

  @override
  Future<void> saveUserPreferences({
    required String userId,
    required UserPreferences preferences,
  }) async {
    _preferences = preferences;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String testUserId = 'test-user';
  final LocalStorageService localStorage = LocalStorageService.instance;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await localStorage.initialize();
    await localStorage.configureForUser(testUserId);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await localStorage.configureForUser(testUserId);
    await localStorage.clearCachedReports();
  });

  tearDown(() async {
    await localStorage.clearCachedReports();
  });

  test('double synchronization keeps Supabase IDs without duplicating reports', () async {
    final DateTime createdAt = DateTime(2024, 1, 1, 12);
    final Report remoteReport = Report(
      id: 'remote-1',
      typeId: ReportType.security.id,
      description: 'Remote description',
      createdAt: createdAt,
      latitude: 10.0,
      longitude: -10.0,
    );

    final _FakeSupabaseService supabase = _FakeSupabaseService(
      reports: <Report>[remoteReport],
    );
    final StorageService storage = StorageService(
      localStorage: localStorage,
      supabase: supabase,
    );

    await storage.initializeForUser(testUserId);
    expect(storage.reports.length, 1);
    expect(storage.reports.first.id, remoteReport.id);

    await storage.syncReportsFromSupabase();

    expect(storage.reports.length, 1);
    expect(storage.reports.first.id, remoteReport.id);
    expect(storage.reports.first.createdAt, createdAt);
  });

  test('remote deletions are reflected locally without duplicating cached reports', () async {
    final Report firstReport = Report(
      id: 'supabase-1',
      typeId: ReportType.security.id,
      description: 'First remote report',
      createdAt: DateTime(2024, 1, 2, 8),
    );
    final Report secondReport = Report(
      id: 'supabase-2',
      typeId: ReportType.service.id,
      description: 'Second remote report',
      createdAt: DateTime(2024, 1, 3, 10),
    );

    final _FakeSupabaseService supabase = _FakeSupabaseService(
      reports: <Report>[firstReport, secondReport],
    );
    final StorageService storage = StorageService(
      localStorage: localStorage,
      supabase: supabase,
    );

    await storage.initializeForUser(testUserId);
    expect(storage.reports.length, 2);

    supabase.setReports(<Report>[secondReport]);

    await storage.syncReportsFromSupabase();

    expect(storage.reports.length, 1);
    expect(storage.reports.first.id, secondReport.id);
    expect(storage.reports.first.description, secondReport.description);
  });

  test('_loadStoredReports ignores invalid cached entries', () async {
    final Box<Map<String, dynamic>> box =
        Hive.box<Map<String, dynamic>>('reports_box_$testUserId');
    await box.clear();

    final Report validReport = Report(
      id: 'valid-report',
      typeId: ReportType.security.id,
      description: 'Valid cached report',
      createdAt: DateTime(2024, 5, 1),
    );

    await box.put('valid-report', validReport.toJson());
    await box.put('invalid-report', <String, dynamic>{
      'id': 'invalid-report',
      'typeId': ReportType.service.id,
      'description': 'Invalid cached report',
      'createdAt': <String, String>{'oops': 'value'},
    });

    await localStorage.configureForUser(testUserId);

    final List<Report> reports = localStorage.reports;
    expect(reports.length, 1);
    expect(reports.first.id, validReport.id);
  });
}
