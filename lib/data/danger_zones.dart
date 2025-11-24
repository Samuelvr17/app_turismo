import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/danger_zone.dart';

/// Lista centralizada de zonas de peligro conocidas por la aplicación.
const List<DangerZone> kDangerZones = <DangerZone>[
  DangerZone(
    id: 'vereda_1',
    center: LatLng(4.1161999958575795, -73.6088337333233),
    title: 'Vereda 1',
    description: 'info relevante',
    specificDangers: 'peligros del área',
    securityRecommendations: 'recomendaciones',
    radius: 120,
    overlayHeight: 18,
  ),
];
