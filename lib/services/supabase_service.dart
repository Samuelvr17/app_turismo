import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/report.dart';
import '../models/safe_route.dart';
import '../models/user_preferences.dart';
import 'reports_remote_data_source.dart';

class SupabaseService implements ReportsRemoteDataSource {
  SupabaseService._();

  static final SupabaseService instance = SupabaseService._();

  bool _isInitialized = false;
  SupabaseClient? _client;

  SupabaseClient get client {
    if (_client == null) {
      throw StateError('Supabase has not been initialized');
    }
    return _client!;
  }

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    final String supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    final String supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'SUPABASE_URL y SUPABASE_ANON_KEY deben estar configuradas en el archivo .env',
      );
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );

    _client = Supabase.instance.client;
    _isInitialized = true;
  }

  @override
  Future<Report> saveReport({
    required String userId,
    required ReportType type,
    required String description,
    double? latitude,
    double? longitude,
  }) async {
    final Map<String, dynamic> data = {
      'type_id': type.id,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'user_id': userId,
    };

    final response = await client
        .from('reports')
        .insert(data)
        .select()
        .maybeSingle();

    if (response == null) {
      throw Exception('Error al guardar el reporte en Supabase');
    }

    return Report(
      id: response['id'].toString(),
      typeId: response['type_id'] as String,
      description: response['description'] as String,
      createdAt: DateTime.parse(response['created_at'] as String),
      latitude: (response['latitude'] as num?)?.toDouble(),
      longitude: (response['longitude'] as num?)?.toDouble(),
    );
  }

  @override
  Future<List<Report>> getReports({required String userId}) async {
    final response = await client
        .from('reports')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((item) => Report(
              id: item['id'].toString(),
              typeId: item['type_id'] as String,
              description: item['description'] as String,
              createdAt: DateTime.parse(item['created_at'] as String),
              latitude: (item['latitude'] as num?)?.toDouble(),
              longitude: (item['longitude'] as num?)?.toDouble(),
            ))
        .toList();
  }

  @override
  Future<void> deleteReport({
    required String id,
    required String userId,
  }) async {
    await client
        .from('reports')
        .delete()
        .eq('id', id)
        .eq('user_id', userId);
  }

  @override
  Future<void> saveUserPreferences({
    required String userId,
    required UserPreferences preferences,
  }) async {
    final Map<String, dynamic> data = {
      'user_id': userId,
      'preferred_report_type_id': preferences.preferredReportTypeId,
      'share_location': preferences.shareLocation,
    };

    await client
        .from('user_preferences')
        .upsert(data, onConflict: 'user_id');
  }

  @override
  Future<UserPreferences?> getUserPreferences({required String userId}) async {
    final response = await client
        .from('user_preferences')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return UserPreferences(
      preferredReportTypeId: response['preferred_report_type_id'] as String?,
      shareLocation: response['share_location'] as bool? ?? true,
    );
  }

  @override
  Future<void> saveSafeRoutes({
    required String userId,
    required List<SafeRoute> routes,
  }) async {
    final List<Map<String, dynamic>> data = routes
        .map((route) => {
              'user_id': userId,
              'name': route.name,
              'duration': route.duration,
              'difficulty': route.difficulty,
              'description': route.description,
              'points_of_interest': route.pointsOfInterest,
            })
        .toList();

    await client
        .from('safe_routes')
        .upsert(data, onConflict: 'user_id,name');
  }

  @override
  Future<List<SafeRoute>> getSafeRoutes({required String userId}) async {
    final response = await client
        .from('safe_routes')
        .select()
        .eq('user_id', userId);

    return (response as List<dynamic>)
        .map((item) => SafeRoute(
              name: item['name'] as String,
              duration: item['duration'] as String,
              difficulty: item['difficulty'] as String,
              description: item['description'] as String,
              pointsOfInterest: (item['points_of_interest'] as List<dynamic>)
                  .map((e) => e.toString())
                  .toList(),
            ))
        .toList();
  }
}
