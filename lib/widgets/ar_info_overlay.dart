import 'package:flutter/material.dart';

import '../models/danger_zone.dart';

class ArInfoOverlay extends StatelessWidget {
  const ArInfoOverlay({
    super.key,
    required this.zone,
  });

  final DangerZone zone;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      color: Colors.black.withOpacity(0.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              zone.name,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (zone.summary != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                zone.summary!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
            const SizedBox(height: 12),
            _buildSection(
              context,
              label: 'PELIGROS',
              color: Colors.red.shade400,
              icon: '⚠️',
              items: zone.dangers,
            ),
            const SizedBox(height: 8),
            _buildSection(
              context,
              label: 'PRECAUCIONES',
              color: Colors.amber.shade400,
              icon: '🛡️',
              items: zone.precautions,
            ),
            const SizedBox(height: 8),
            _buildSection(
              context,
              label: 'RECOMENDACIONES',
              color: Colors.green.shade400,
              icon: '✓',
              items: zone.recommendations,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String label,
    required Color color,
    required String icon,
    required List<String> items,
  }) {
    final TextStyle? headerStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        );
    final TextStyle? itemStyle = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(color: Colors.white.withOpacity(0.9));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.18),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.45)),
          ),
          child: Row(
            children: <Widget>[
              Text(icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(label, style: headerStyle),
            ],
          ),
        ),
        const SizedBox(height: 6),
        if (items.isEmpty)
          Text(
            'Sin información disponible',
            style: itemStyle,
          )
        else
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('• ', style: itemStyle),
                  Expanded(
                    child: Text(
                      item,
                      style: itemStyle,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
