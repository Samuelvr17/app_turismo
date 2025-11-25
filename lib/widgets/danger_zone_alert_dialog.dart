import 'package:flutter/material.dart';

import '../models/danger_zone.dart';

class DangerZoneAlertDialog extends StatelessWidget {
  const DangerZoneAlertDialog({
    super.key,
    required this.zone,
    required this.onDismiss,
    required this.onOpenAr,
  });

  final DangerZone zone;
  final VoidCallback onDismiss;
  final VoidCallback onOpenAr;

  Color _badgeColor() {
    switch (zone.level) {
      case DangerLevel.high:
        return Colors.red.shade700;
      case DangerLevel.medium:
        return Colors.orange.shade700;
      case DangerLevel.low:
        return Colors.yellow.shade800;
    }
  }

  String _badgeLabel() {
    switch (zone.level) {
      case DangerLevel.high:
        return 'Alta';
      case DangerLevel.medium:
        return 'Media';
      case DangerLevel.low:
        return 'Baja';
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      title: Row(
        children: [
          const Icon(Icons.warning_rounded, color: Colors.red, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Zona peligrosa detectada', style: textTheme.titleMedium),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _badgeColor().withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _badgeColor()),
                  ),
                  child: Text(
                    'Nivel ${_badgeLabel()}',
                    style: textTheme.bodySmall?.copyWith(
                      color: _badgeColor(),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(zone.title, style: textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(zone.description, style: textTheme.bodyMedium),
              const SizedBox(height: 12),
              Text('Peligros específicos', style: textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(zone.specificDangers),
              const SizedBox(height: 12),
              Text('Precauciones obligatorias', style: textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(zone.precautions),
              const SizedBox(height: 12),
              Text('Recomendaciones de seguridad', style: textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(zone.securityRecommendations),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: onDismiss,
          child: const Text('Entendido'),
        ),
        FilledButton.icon(
          onPressed: onOpenAr,
          icon: const Icon(Icons.view_in_ar),
          label: const Text('Ver en AR'),
        ),
      ],
    );
  }
}