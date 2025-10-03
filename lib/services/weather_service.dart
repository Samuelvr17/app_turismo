import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/weather_data.dart';

class WeatherService {
  WeatherService._();

  static final WeatherService instance = WeatherService._();

  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5/weather';
  static const String _apiKey = String.fromEnvironment('OPENWEATHER_API_KEY');
  
  Timer? _updateTimer;
  final ValueNotifier<WeatherData?> _weatherNotifier = ValueNotifier<WeatherData?>(null);
  double? _lastLatitude;
  double? _lastLongitude;
  
  ValueListenable<WeatherData?> get weatherListenable => _weatherNotifier;
  WeatherData? get currentWeather => _weatherNotifier.value;
  
  void startAutoUpdate({
    required double latitude,
    required double longitude,
  }) {
    _lastLatitude = latitude;
    _lastLongitude = longitude;
    
    // Cancelar timer anterior si existe
    _updateTimer?.cancel();
    
    // Obtener datos inmediatamente
    _updateWeatherData();
    
    // Configurar actualización automática cada 12 minutos
    _updateTimer = Timer.periodic(const Duration(minutes: 12), (_) {
      _updateWeatherData();
    });
  }
  
  void stopAutoUpdate() {
    _updateTimer?.cancel();
    _updateTimer = null;
  }
  
  Future<void> _updateWeatherData() async {
    if (_lastLatitude == null || _lastLongitude == null) return;
    
    try {
      final weatherData = await getWeatherByCoordinates(
        latitude: _lastLatitude!,
        longitude: _lastLongitude!,
      );
      _weatherNotifier.value = weatherData;
    } catch (error) {
      if (kDebugMode) {
        print('Error en actualización automática del clima: $error');
      }
    }
  }

  Future<WeatherData?> getWeatherByCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    if (_apiKey.isEmpty) {
      if (kDebugMode) {
        print('OpenWeatherMap API key not found. Make sure to set OPENWEATHER_API_KEY environment variable.');
      }
      return null;
    }

    try {

      // AGREGAR ESTE LOG
      if (kDebugMode) {
        print('📍 Enviando coordenadas: Lat: ${latitude.toStringAsFixed(6)}, Lng: ${longitude.toStringAsFixed(6)}');
      }

      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'appid': _apiKey,
        'units': 'metric',
        'lang': 'es',
      });

      // AGREGAR ESTE LOG PARA VER LA URL COMPLETA
    if (kDebugMode) {
      print('🌐 URL de la petición: $uri');
    }

      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Request timeout', const Duration(seconds: 10)),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body) as Map<String, dynamic>;

        // AGREGAR LOG CON LA CIUDAD DEVUELTA POR LA API
      if (kDebugMode) {
        print('✅ Clima obtenido para: ${data['name']}, ${data['sys']['country']}');
      }

        return WeatherData.fromJson(data);
      } else {
        if (kDebugMode) {
          print('Weather API error: ${response.statusCode} - ${response.body}');
        }
        return null;
      }
    } catch (error) {
      if (kDebugMode) {
        print('Error fetching weather data: $error');
      }
      return null;
    }
  }
  
  void dispose() {
    _updateTimer?.cancel();
    _weatherNotifier.dispose();
  }
}