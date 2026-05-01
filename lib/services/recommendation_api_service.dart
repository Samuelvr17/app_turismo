import 'dart:async';
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
        'No se encontró la url del servidor AI (RECOMMENDATION_API_URL). Verifica el archivo .env y vuelve a compilar.',
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

    debugPrint('[RecommendationApiService] Solicitando recomendaciones a: $endpoint');

    try {
      final http.Response response = await _httpClient.post(
        endpoint,
        headers: const <String, String>{
          'Content-Type': 'application/json',
        },
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 20));

      debugPrint('[RecommendationApiService] Respuesta recibida HTTP ${response.statusCode}');

      if (response.statusCode >= 400) {
        throw RecommendationApiException(
          'Error en el servidor al generar recomendaciones (Código: ${response.statusCode}).',
        );
      }

      final Map<String, dynamic> decoded =
          json.decode(response.body) as Map<String, dynamic>;
      final List<dynamic> rawRecommendations =
          decoded['recommendations'] as List<dynamic>? ?? <dynamic>[];

      return rawRecommendations
          .map((dynamic item) => ActivityRecommendation.fromJson(
                Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
              ))
          .toList();
    } on TimeoutException catch (error) {
      debugPrint('[RecommendationApiService] Timeout al conectar con AI service: $error');
      throw RecommendationApiException(
        'El servicio AI tardó demasiado en responder. Por favor, intenta de nuevo (Timeout).',
      );
    } on http.ClientException catch (error) {
      debugPrint('[RecommendationApiService] Error de red ClientException: $error');
      throw RecommendationApiException(
        'Hubo un problema de conexión al servidor AI. Verifica tu red o la URL configurada.',
      );
    } on FormatException catch (error) {
      debugPrint('[RecommendationApiService] Respuesta JSON inválida: $error');
      throw RecommendationApiException(
        'El formato de la respuesta del servidor es inválido.',
      );
    } catch (error) {
      debugPrint('[RecommendationApiService] Error inesperado en API de recomendaciones: $error');
      if (error.toString().contains('SocketException')) {
        throw RecommendationApiException(
          'No se pudo conectar al servidor de recomendaciones. Verifica que tu dispositivo alcance la red (SocketException).',
        );
      }
      if (error is RecommendationApiException) rethrow;
      throw RecommendationApiException(
        'Ocurrió un error general inesperado al pedir recomendaciones.',
      );
    }
  }
}
