import '../models/safe_route.dart';

const List<SafeRoute> defaultSafeRoutes = <SafeRoute>[
  SafeRoute(
    name: 'Vereda Buenavista',
    duration: 'A 15 minutos de Villavicencio',
    difficulty: 'Actividades para todos',
    description:
        '🍃 La vereda Buenavista ofrece un clima distinto en Villavicencio, a tan solo '
        '15 minutos de su casco urbano, ideal para el turismo deportivo, de naturaleza '
        'y religioso.',
    pointsOfInterest: <String>[
      'Miradores',
      'Parapente',
      'Caminata ecológica',
    ],
  ),
  SafeRoute(
    name: 'Vereda Argentina',
    duration: 'A 20 minutos de Villavicencio',
    difficulty: 'Naturaleza y aventura',
    description:
        '🚴‍♀️ La vereda Argentina combina montañas, paisajes llaneros y caminos '
        'ideales para disfrutar de actividades al aire libre con toda la familia.',
    pointsOfInterest: <String>[
      'Ciclismo',
      'Caminata',
    ],
  ),
];
