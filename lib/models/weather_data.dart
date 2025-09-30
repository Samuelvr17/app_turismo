import 'package:flutter/foundation.dart';

@immutable
class WeatherData {
  const WeatherData({
    required this.temperature,
    required this.description,
    required this.humidity,
    required this.windSpeed,
    required this.iconCode,
    required this.feelsLike,
    required this.pressure,
    required this.windDirection,
    required this.windGust,
    required this.visibility,
  });

  final double temperature;
  final String description;
  final int humidity;
  final double windSpeed;
  final String iconCode;
  final double feelsLike;
  final int pressure;
  final int windDirection;
  final double windGust;
  final int visibility;

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final main = json['main'] as Map<String, dynamic>;
    final weather = (json['weather'] as List<dynamic>).first as Map<String, dynamic>;
    final wind = json['wind'] as Map<String, dynamic>? ?? <String, dynamic>{};

    return WeatherData(
      temperature: (main['temp'] as num).toDouble(),
      description: weather['description'] as String,
      humidity: main['humidity'] as int,
      windSpeed: (wind['speed'] as num?)?.toDouble() ?? 0.0,
      iconCode: weather['icon'] as String,
      feelsLike: (main['feels_like'] as num).toDouble(),
      pressure: main['pressure'] as int,
      windDirection: (wind['deg'] as num?)?.toInt() ?? 0,
      windGust: (wind['gust'] as num?)?.toDouble() ?? 0.0,
      visibility: (json['visibility'] as num?)?.toInt() ?? 0,
    );
  }

  String get temperatureFormatted => '${temperature.round()}°C';
  String get feelsLikeFormatted => '${feelsLike.round()}°C';
  String get windSpeedFormatted => '${windSpeed.toStringAsFixed(1)} m/s';
  String get humidityFormatted => '$humidity%';
  String get pressureFormatted => '$pressure hPa';
  String get windDirectionFormatted => '${windDirection}°';
  String get windGustFormatted => '${windGust.toStringAsFixed(1)} m/s';
  String get visibilityFormatted => '${(visibility / 1000).toStringAsFixed(1)} km';
  
  String get windDirectionCardinal {
    if (windDirection >= 337.5 || windDirection < 22.5) return 'N';
    if (windDirection >= 22.5 && windDirection < 67.5) return 'NE';
    if (windDirection >= 67.5 && windDirection < 112.5) return 'E';
    if (windDirection >= 112.5 && windDirection < 157.5) return 'SE';
    if (windDirection >= 157.5 && windDirection < 202.5) return 'S';
    if (windDirection >= 202.5 && windDirection < 247.5) return 'SW';
    if (windDirection >= 247.5 && windDirection < 292.5) return 'W';
    if (windDirection >= 292.5 && windDirection < 337.5) return 'NW';
    return 'N';
  }
  
  String get iconUrl => 'https://openweathermap.org/img/wn/$iconCode@2x.png';
}