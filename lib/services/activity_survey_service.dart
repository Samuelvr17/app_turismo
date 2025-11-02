import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/activity_recommendation.dart';
import '../models/activity_survey.dart';
import '../models/available_activity.dart';
import '../models/safe_route.dart';
import '../data/default_safe_routes.dart';
import 'recommendation_api_service.dart';
import 'supabase_service.dart';

class ActivitySurveyService {
  ActivitySurveyService._({
    SupabaseClient? client,
    RecommendationApiService? apiService,
  })  : _client = client,
        _apiService = apiService ?? RecommendationApiService();

  static final ActivitySurveyService instance = ActivitySurveyService._();

  final SupabaseClient? _client;
  final RecommendationApiService _apiService;

  SupabaseClient get _supabaseClient => _client ?? SupabaseService.instance.client;

  String? _currentUserId;
  bool _isInitialized = false;

  final ValueNotifier<ActivitySurvey?> _surveyNotifier =
      ValueNotifier<ActivitySurvey?>(null);
  final ValueNotifier<List<ActivityRecommendation>> _recommendationsNotifier =
      ValueNotifier<List<ActivityRecommendation>>(<ActivityRecommendation>[]);

  ValueListenable<ActivitySurvey?> get surveyListenable => _surveyNotifier;
  ValueListenable<List<ActivityRecommendation>> get recommendationsListenable =>
      _recommendationsNotifier;

  bool get hasCompletedSurvey => _surveyNotifier.value != null;

  Future<void> initializeForUser(String userId) async {
    if (_isInitialized && _currentUserId == userId) {
      return;
    }

    _currentUserId = userId;

    try {
      final ActivitySurvey? survey = await _fetchSurvey(userId);
      _surveyNotifier.value = survey;
    } catch (error) {
      debugPrint('Error al cargar encuesta del usuario: $error');
      _surveyNotifier.value = null;
    }

    try {
      final List<ActivityRecommendation> recommendations =
          await _fetchRecommendations(userId);
      _recommendationsNotifier.value = recommendations;
    } catch (error) {
      debugPrint('Error al cargar recomendaciones del usuario: $error');
      _recommendationsNotifier.value = <ActivityRecommendation>[];
    }

    _isInitialized = true;
  }

  Future<ActivitySurvey?> _fetchSurvey(String userId) async {
    final Map<String, dynamic>? response = await _supabaseClient
        .from('user_activity_surveys')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    final Map<String, dynamic> rawResponses =
        Map<String, dynamic>.from(
      response['responses'] as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{},
    );

    final ActivitySurvey baseSurvey = ActivitySurvey.fromJson(rawResponses);
    final DateTime? completedAt = (response['completed_at'] as String?) != null
        ? DateTime.tryParse(response['completed_at'] as String)
        : baseSurvey.completedAt;

    return baseSurvey.copyWith(completedAt: completedAt);
  }

  Future<List<ActivityRecommendation>> _fetchRecommendations(
    String userId,
  ) async {
    final List<dynamic> response = await _supabaseClient
        .from('activity_recommendations')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return response
        .map((dynamic item) {
          final Map<String, dynamic> data =
              Map<String, dynamic>.from(item as Map<dynamic, dynamic>);
          return ActivityRecommendation.fromJson(<String, dynamic>{
            'activityName': data['activity_name'],
            'summary': data['summary'],
            'location': data['location'],
            'confidence': data['confidence'],
            'tags': data['tags'],
            'createdAt': data['created_at'],
          });
        })
        .toList();
  }

  Future<void> submitSurvey(ActivitySurvey survey) async {
    final String userId = _ensureUserId();
    final DateTime completedAt = DateTime.now().toUtc();
    final ActivitySurvey surveyToSave =
        survey.copyWith(completedAt: completedAt);

    await _supabaseClient.from('user_activity_surveys').upsert(
      <String, dynamic>{
        'user_id': userId,
        'responses': surveyToSave.toJson(),
        'completed_at': completedAt.toIso8601String(),
      },
      onConflict: 'user_id',
    );

    _surveyNotifier.value = surveyToSave;

    final List<AvailableActivity> availableActivities =
        await _loadAvailableActivities();

    final List<ActivityRecommendation> recommendations =
        await _apiService.generateRecommendations(
      userId: userId,
      survey: surveyToSave,
      availableActivities: availableActivities,
    );

    await _persistRecommendations(userId, recommendations);
    _recommendationsNotifier.value = recommendations;
  }

  Future<void> refreshRecommendations() async {
    final String userId = _ensureUserId();
    final ActivitySurvey? survey = _surveyNotifier.value;
    if (survey == null) {
      throw StateError('No se ha completado el cuestionario del usuario.');
    }

    final List<AvailableActivity> availableActivities =
        await _loadAvailableActivities();

    final List<ActivityRecommendation> recommendations =
        await _apiService.generateRecommendations(
      userId: userId,
      survey: survey,
      availableActivities: availableActivities,
    );
    await _persistRecommendations(userId, recommendations);
    _recommendationsNotifier.value = recommendations;
  }

  Future<void> _persistRecommendations(
    String userId,
    List<ActivityRecommendation> recommendations,
  ) async {
    await _supabaseClient
        .from('activity_recommendations')
        .delete()
        .eq('user_id', userId);

    if (recommendations.isEmpty) {
      return;
    }

    final List<Map<String, dynamic>> payload = recommendations
        .map((ActivityRecommendation recommendation) => <String, dynamic>{
              'user_id': userId,
              'activity_name': recommendation.activityName,
              'summary': recommendation.summary,
              'location': recommendation.location,
              'confidence': recommendation.confidence,
              'tags': recommendation.tags,
              'created_at': recommendation.createdAt.toUtc().toIso8601String(),
            })
        .toList();

    await _supabaseClient.from('activity_recommendations').insert(payload);
  }

  Future<void> clearForSignOut() async {
    _currentUserId = null;
    _isInitialized = false;
    _surveyNotifier.value = null;
    _recommendationsNotifier.value = <ActivityRecommendation>[];
  }

  String _ensureUserId() {
    final String? userId = _currentUserId;
    if (userId == null) {
      throw StateError('No hay un usuario autenticado configurado.');
    }
    return userId;
  }

  Future<List<AvailableActivity>> _loadAvailableActivities() async {
    List<SafeRoute> routes = <SafeRoute>[];

    try {
      final List<dynamic> response = await _supabaseClient
          .from('safe_routes')
          .select('name, description, difficulty, points_of_interest');

      routes = response
          .map((dynamic item) {
            final Map<String, dynamic> data =
                Map<String, dynamic>.from(item as Map<dynamic, dynamic>);
            return SafeRoute(
              name: data['name'] as String? ?? '',
              duration: '',
              difficulty: data['difficulty'] as String? ?? '',
              description: data['description'] as String? ?? '',
              pointsOfInterest: (data['points_of_interest'] as List<dynamic>? ??
                      <dynamic>[])
                  .map((dynamic value) => value.toString())
                  .where((String value) => value.trim().isNotEmpty)
                  .toList(),
            );
          })
          .where((SafeRoute route) => route.pointsOfInterest.isNotEmpty)
          .toList();
    } catch (error) {
      debugPrint('Error al cargar actividades disponibles: $error');
    }

    if (routes.isEmpty) {
      routes = defaultSafeRoutes;
    }

    final Set<String> seen = <String>{};
    final List<AvailableActivity> activities = <AvailableActivity>[];

    for (final SafeRoute route in routes) {
      for (final String activity in route.pointsOfInterest) {
        final String key = '${route.name}::$activity'.toLowerCase();
        if (seen.add(key)) {
          activities.add(AvailableActivity.fromSafeRoute(route, activity));
        }
      }
    }

    return activities;
  }
}
