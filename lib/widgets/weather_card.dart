import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/weather_data.dart';

class WeatherCard extends StatelessWidget {
  const WeatherCard({
    super.key,
    required this.weatherData,
    this.syncTime,
  });

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  final WeatherData weatherData;
  final DateTime? syncTime;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.wb_sunny,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Clima actual',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (syncTime != null)
                  Text(
                    'Actualizado: ${_formatTime(syncTime!)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  )
                else
                  Text(
                    'Actualiza cada 12 min',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        weatherData.temperatureFormatted,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        weatherData.description.toUpperCase(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sensación térmica: ${weatherData.feelsLikeFormatted}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CachedNetworkImage(
                    imageUrl: weatherData.iconUrl,
                    width: 80,
                    height: 80,
                    placeholder: (BuildContext context, String url) => const Center(
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (BuildContext context, String url, dynamic error) =>
                        Icon(
                      Icons.cloud,
                      size: 80,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _WeatherDetail(
                    icon: Icons.water_drop,
                    label: 'Humedad',
                    value: weatherData.humidityFormatted,
                  ),
                ),
                Expanded(
                  child: _WeatherDetail(
                    icon: Icons.air,
                    label: 'Viento',
                    value: weatherData.windSpeedFormatted,
                  ),
                ),
                Expanded(
                  child: _WeatherDetail(
                    icon: Icons.speed,
                    label: 'Presión',
                    value: weatherData.pressureFormatted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _WeatherDetail(
                    icon: Icons.explore,
                    label: 'Dirección',
                    value: '${weatherData.windDirectionCardinal} (${weatherData.windDirectionFormatted})',
                  ),
                ),
                Expanded(
                  child: _WeatherDetail(
                    icon: Icons.air,
                    label: 'Ráfagas',
                    value: weatherData.windGustFormatted,
                  ),
                ),
                Expanded(
                  child: _WeatherDetail(
                    icon: Icons.visibility,
                    label: 'Visibilidad',
                    value: weatherData.visibilityFormatted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeatherDetail extends StatelessWidget {
  const _WeatherDetail({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}