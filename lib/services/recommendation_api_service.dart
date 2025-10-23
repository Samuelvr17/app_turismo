import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/activity_recommendation.dart';
import '../models/activity_survey.dart';
import '../models/available_activity.dart';

class RecommendationApiException implements Exception {
  RecommendationApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RecommendationApiService {
  RecommendationApiService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Uri _buildEndpoint(String path) {
    final String? baseUrl = dotenv.env['RECOMMENDATION_API_URL'];
    if (baseUrl == null || baseUrl.isEmpty) {
      throw RecommendationApiException(
        'RECOMMENDATION_API_URL no está configurada en el archivo .env',
      );
    }

    return Uri.parse(baseUrl).resolve(path);
  }

  Future<List<ActivityRecommendation>> generateRecommendations({
    required String userId,
    required ActivitySurvey survey,
    required List<AvailableActivity> availableActivities,
  }) async {
    final Uri endpoint = _buildEndpoint('/v1/recommendations');
    final Map<String, dynamic> payload = <String, dynamic>{
      'user_id': userId,
      'survey': survey.toJson(),
      'availableActivities':
          availableActivities.map((AvailableActivity item) => item.toJson()).toList(),
    };

    final http.Response response = await _httpClient.post(
      endpoint,
      headers: const <String, String>{
        'Content-Type': 'application/json',
      },
      body: json.encode(payload),
    );

    if (response.statusCode >= 400) {
      throw RecommendationApiException(
        'Error al solicitar recomendaciones (${response.statusCode})',
      );
    }

    try {
      final Map<String, dynamic> decoded =
          json.decode(response.body) as Map<String, dynamic>;
      final List<dynamic> rawRecommendations =
          decoded['recommendations'] as List<dynamic>? ?? <dynamic>[];

      return rawRecommendations
          .map((dynamic item) => ActivityRecommendation.fromJson(
                Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
              ))
          .toList();
    } catch (error, stackTrace) {
      debugPrint('Error al decodificar recomendaciones: $error');
      debugPrint('$stackTrace');
      throw RecommendationApiException(
        'No fue posible interpretar la respuesta del servicio de recomendaciones',
      );
    }
  }
}
