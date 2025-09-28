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
  });

  final double temperature;
  final String description;
  final int humidity;
  final double windSpeed;
  final String iconCode;
  final double feelsLike;
  final int pressure;

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
    );
  }

  String get temperatureFormatted => '${temperature.round()}°C';
  String get feelsLikeFormatted => '${feelsLike.round()}°C';
  String get windSpeedFormatted => '${windSpeed.toStringAsFixed(1)} m/s';
  String get humidityFormatted => '$humidity%';
  String get pressureFormatted => '$pressure hPa';
  String get iconUrl => 'https://openweathermap.org/img/wn/$iconCode@2x.png';
}