import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:panorama_viewer/panorama_viewer.dart';

import '../data/default_safe_routes.dart';
import '../models/safe_route.dart';
import '../models/weather_data.dart';
import '../services/route_data_service.dart';
import '../services/safe_route_local_data_source.dart';
import '../services/weather_service.dart';
import '../widgets/weather_card.dart';

class RutasSegurasPage extends StatefulWidget {
  const RutasSegurasPage({super.key});

  @override
  State<RutasSegurasPage> createState() => _RutasSegurasPageState();
}

class _RutasSegurasPageState extends State<RutasSegurasPage> {
  static const LatLng _defaultRouteLocation =
      LatLng(4.157296670026874, -73.68158509824853);

  final RouteDataService _routeDataService = RouteDataService.instance;
  final SafeRouteLocalDataSource _localDataSource = SafeRouteLocalDataSource();
  
  List<SafeRoute> _routes = const <SafeRoute>[];
  Map<String, LatLng> _routeLocations = {};
  Map<String, Map<String, List<String>>> _routeActivityImages = {};
  
  bool _isLoading = true;
  bool _isLoadingRouteData = true;
  String? _routeDataError;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    // Cargar rutas y datos de ubicaciones/imágenes en paralelo
    await Future.wait([
      _initializeRoutes(),
      _initializeRouteData(),
    ]);
  }

  Future<void> _initializeRoutes() async {
    try {
      final List<SafeRoute> routes = await _localDataSource.loadRoutes();

      if (!mounted) {
        return;
      }

      setState(() {
        _routes = routes.isNotEmpty ? routes : defaultSafeRoutes;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _routes = defaultSafeRoutes;
        _isLoading = false;
      });
    }
  }

  Future<void> _initializeRouteData() async {
    try {
      // Cargar ubicaciones e imágenes desde Supabase
      final locations = await _routeDataService.getRouteLocations();
      final images = await _routeDataService.getAllActivityImages();

      if (!mounted) {
        return;
      }

      setState(() {
        _routeLocations = locations;
        _routeActivityImages = images;
        _isLoadingRouteData = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _routeDataError = 'No se pudieron cargar los datos de rutas: $error';
        _isLoadingRouteData = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final ThemeData theme = Theme.of(context);

    return Column(
      children: [
        if (_routeDataError != null)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: theme.colorScheme.onErrorContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _routeDataError!,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.separated(

      padding: const EdgeInsets.all(16),
      itemCount: _routes.length,
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: 16),
      itemBuilder: (BuildContext context, int index) {
        final SafeRoute route = _routes[index];

        return Card(
          elevation: 1,
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  route.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    _RouteInfo(icon: Icons.schedule, label: route.duration),
                    _RouteInfo(icon: Icons.terrain, label: route.difficulty),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  route.description,
                  style: theme.textTheme.bodyMedium,
                ),
                if (route.pointsOfInterest.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    'Puntos de interés',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: route.pointsOfInterest
                        .map(
                          (String point) => ActionChip(
                            label: Text(point),
                            onPressed: () =>
                                _openActivityDetail(route: route, activity: point),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    ),
        ),
      ],
    );
  }


  void _openActivityDetail({
    required SafeRoute route,
    required String activity,
  }) {
    final List<String> imageUrls = _routeActivityImages[route.name]?[activity] ??
        const <String>[];
    final LatLng location =
        _routeLocations[route.name] ?? _defaultRouteLocation;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => SafeRouteActivityDetailPage(
          routeName: route.name,
          activityName: activity,
          routeDescription: route.description,
          location: location,
          imageUrls: imageUrls,
        ),
      ),
    );
  }
}

class _RouteInfo extends StatelessWidget {
  const _RouteInfo({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

class SafeRouteActivityDetailPage extends StatefulWidget {
  const SafeRouteActivityDetailPage({
    super.key,
    required this.routeName,
    required this.activityName,
    required this.routeDescription,
    required this.location,
    required this.imageUrls,
  });

  final String routeName;
  final String activityName;
  final String routeDescription;
  final LatLng location;
  final List<String> imageUrls;

  @override
  State<SafeRouteActivityDetailPage> createState() => _SafeRouteActivityDetailPageState();
}

class _SafeRouteActivityDetailPageState extends State<SafeRouteActivityDetailPage> {
  final WeatherService _weatherService = WeatherService.instance;
  WeatherData? _weatherData;
  bool _isLoadingWeather = true;
  String? _weatherError;
  VoidCallback? _weatherListener;
  late final bool _isParaglidingActivity;
  late final bool _shouldShowWeather;
  late final PageController _pageController;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    final String normalizedActivity = widget.activityName.toLowerCase();
    _isParaglidingActivity = normalizedActivity.contains('parapente');
    _shouldShowWeather = _isParaglidingActivity;

    if (_shouldShowWeather) {
      _weatherListener = () {
        if (!mounted) {
          return;
        }

        setState(() {
          _weatherData = _weatherService.currentWeather;
          _isLoadingWeather = false;
          _weatherError = _weatherData == null
              ? 'No se pudo obtener información del clima'
              : null;
        });
      };

      _weatherService.weatherListenable.addListener(_weatherListener!);
      _startWeatherUpdates();
    } else {
      _isLoadingWeather = false;
    }
  }

  @override
  void dispose() {
    if (_shouldShowWeather) {
      if (_weatherListener != null) {
        _weatherService.weatherListenable.removeListener(_weatherListener!);
      }
      _weatherService.stopAutoUpdate();
    }
    _pageController.dispose();
    super.dispose();
  }

  void _startWeatherUpdates() {
    // Iniciar actualización automática del clima
    _weatherService.startAutoUpdate(
      latitude: widget.location.latitude,
      longitude: widget.location.longitude,
    );

    // Si ya hay datos disponibles, usarlos inmediatamente
    final currentWeather = _weatherService.currentWeather;
    if (currentWeather != null) {
      setState(() {
        _weatherData = currentWeather;
        _isLoadingWeather = false;
        _weatherError = null;
      });
    } else {
      // Si no hay datos, cargar manualmente la primera vez
      _loadWeatherDataManually();
    }
  }

  Future<void> _loadWeatherDataManually() async {
    try {
      final weatherData = await _weatherService.getWeatherByCoordinates(
        latitude: widget.location.latitude,
        longitude: widget.location.longitude,
      );

      if (mounted) {
        setState(() {
          _weatherData = weatherData;
          _isLoadingWeather = false;
          _weatherError = weatherData == null ? 'No se pudo obtener información del clima' : null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoadingWeather = false;
          _weatherError = 'Error al cargar el clima: $error';
        });
      }
    }
  }

  List<String> get _safetyConsiderations {
    final String normalizedActivity = widget.activityName.toLowerCase();

    if (normalizedActivity.contains('parapente')) {
      return const <String>[
        'Viento: 5-25 km/h (1.4-6.9 m/s) para principiantes.',
        'Ráfagas: No deben superar 8 m/s para mantener el control del velamen.',
        'Visibilidad: Mínimo 1-2 km para evaluar obstáculos y puntos de aterrizaje.',
        'Dirección del viento: Debe ser favorable a la pendiente de despegue y aterrizaje.',
      ];
    }

    return const <String>[
      'Verifica las condiciones climáticas y de seguridad antes de iniciar la actividad.',
      'Lleva equipo de protección acorde a la actividad y en buen estado.',
      'Informa a un contacto de confianza sobre tu ruta y horario estimado.',
    ];
  }

  Widget _buildImageCarousel(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: 240,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            onPageChanged: (int index) {
              setState(() {
                _currentImageIndex = index;
              });
            },
            itemBuilder: (BuildContext context, int index) {
              final String imageUrl = widget.imageUrls[index];
              final Widget content = _isPanoramaImage(imageUrl)
                  ? _buildPanoramaPreview(context, imageUrl)
                  : GestureDetector(
                      onTap: () => _showFullScreenImage(imageUrl),
                      child: _buildImageWidget(imageUrl),
                    );

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: content,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.center,
          child: Text(
            '${_currentImageIndex + 1} de ${widget.imageUrls.length}',
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  bool _isPanoramaImage(String imageUrl) {
    // Detectar imágenes panorámicas por nombre de archivo o metadatos en la URL
    // Las imágenes 360° típicamente tienen "parapente" o "panorama" en el nombre
    final Uri parsed = Uri.parse(imageUrl);
    final String path = parsed.path.toLowerCase();
    final String normalized = imageUrl.toLowerCase();

    // Lista de patrones que indican imágenes panorámicas
    return path.contains('parapente') ||
        path.contains('panorama') ||
        path.contains('360') ||
        path.contains('bryan-goff') || // La imagen específica de parapente
        parsed.queryParameters.containsKey('panorama') ||
        parsed.queryParameters['type'] == 'panorama' ||
        normalized.contains('panorama') ||
        normalized.contains('360');
  }

  Widget _buildPanoramaPreview(BuildContext context, String imageUrl) {
    final ThemeData theme = Theme.of(context);
    final bool isNetworkImage = imageUrl.startsWith('http');

    Widget buildPanoramaChild() {
      if (isNetworkImage) {
        return Image.network(
          imageUrl,
          fit: BoxFit.cover,
          loadingBuilder:
              (BuildContext context, Widget child, ImageChunkEvent? progress) {
            if (progress == null) {
              return child;
            }
            return Center(
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
          errorBuilder:
              (BuildContext context, Object error, StackTrace? stackTrace) {
            return Container(
              color: Colors.black12,
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image_outlined, size: 48),
            );
          },
        );
      }

      return Image.asset(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stackTrace) {
          return Container(
            color: Colors.black12,
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_outlined, size: 48),
          );
        },
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        PanoramaViewer(
          animSpeed: 0.8,
          sensorControl: SensorControl.orientation,
          child: buildPanoramaChild(),
        ),
        Positioned(
          top: 12,
          left: 12,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.threesixty, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Vista 360°',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              backgroundColor:
                  theme.colorScheme.surface.withValues(alpha: 0.85),
            ),
            onPressed: () => _showFullScreenImage(imageUrl),
            icon: const Icon(Icons.open_in_full),
            label: const Text('Pantalla completa'),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePlaceholder(ThemeData theme) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.image_not_supported_outlined,
              size: 48,
              color: theme.colorScheme.onSurface,
            ),
            const SizedBox(height: 8),
            Text(
              'No hay imágenes disponibles para esta actividad.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageWidget(String imageUrl) {
    final bool isNetworkImage = imageUrl.startsWith('http');

    if (isNetworkImage) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        loadingBuilder:
            (BuildContext context, Widget child, ImageChunkEvent? progress) {
          if (progress == null) {
            return child;
          }

          return Center(
            child: SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded /
                        progress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
          return Container(
            color: Colors.black12,
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_outlined, size: 48),
          );
        },
      );
    }

    return Image.asset(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
        return Container(
          color: Colors.black12,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_outlined, size: 48),
        );
      },
    );
  }

  void _showFullScreenImage(String imageUrl) {
    final bool isNetworkImage = imageUrl.startsWith('http');
    final bool isPanorama = _isPanoramaImage(imageUrl);

    Widget buildFullScreenContent() {
      if (isPanorama) {
        return PanoramaViewer(
          animSpeed: 0.8,
          sensorControl: SensorControl.orientation,
          child: isNetworkImage
              ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (BuildContext context, Widget child,
                      ImageChunkEvent? progress) {
                    if (progress == null) {
                      return child;
                    }
                    return Center(
                      child: CircularProgressIndicator(
                        value: progress.expectedTotalBytes != null
                            ? progress.cumulativeBytesLoaded /
                                progress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (BuildContext context, Object error,
                      StackTrace? stackTrace) {
                    return Container(
                      color: Colors.black12,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined, size: 48),
                    );
                  },
                )
              : Image.asset(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (BuildContext context, Object error,
                      StackTrace? stackTrace) {
                    return Container(
                      color: Colors.black12,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined, size: 48),
                    );
                  },
                ),
        );
      }

      if (isNetworkImage) {
        return Image.network(
          imageUrl,
          fit: BoxFit.contain,
          errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
            return Container(
              color: Colors.black12,
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image_outlined, size: 48),
            );
          },
        );
      }

      return Image.asset(
        imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
          return Container(
            color: Colors.black12,
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_outlined, size: 48),
          );
        },
      );
    }

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (BuildContext context) {
        if (isPanorama) {
          return Material(
            color: Colors.black,
            child: Stack(
              children: <Widget>[
                Positioned.fill(child: buildFullScreenContent()),
                Positioned(
                  top: 16,
                  right: 16,
                  child: SafeArea(
                    child: IconButton.filledTonal(
                      style: IconButton.styleFrom(
                        backgroundColor:
                            Colors.black.withValues(alpha: 0.6),
                      ),
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            color: Colors.black,
            alignment: Alignment.center,
            child: InteractiveViewer(child: buildFullScreenContent()),
          ),
        );
      },
    );
  }

  Widget _buildWeatherSection(ThemeData theme) {
    if (!_shouldShowWeather) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Condiciones ambientales',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Para esta actividad no se requiere un monitoreo climático en tiempo real, '
            'pero revisa el pronóstico antes de salir para garantizar una experiencia segura.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      );
    }

    if (_isLoadingWeather) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: <Widget>[
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text('Cargando información del clima para la actividad...'),
            ),
          ],
        ),
      );
    }

    if (_weatherData != null) {
      return WeatherCard(weatherData: _weatherData!);
    }

    if (_weatherError != null) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.warning,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _weatherError!,
                style: TextStyle(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(widget.activityName),
            Text(
              widget.routeName,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onPrimary
                        .withValues(alpha: 0.8),
                  ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (widget.imageUrls.isNotEmpty) ...<Widget>[
                _buildImageCarousel(theme),
                const SizedBox(height: 24),
              ] else ...<Widget>[
                _buildImagePlaceholder(theme),
                const SizedBox(height: 24),
              ],
              _buildWeatherSection(theme),
              const SizedBox(height: 24),
              Text(
                'Consideraciones de seguridad',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              ..._safetyConsiderations.map(
                (String item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('• '),
                      Expanded(
                        child: Text(
                          item,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Consejo rápido',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Recuerda avisar a tus acompañantes o contactos de confianza cuando '
                'inicies y finalices la actividad. Lleva siempre un botiquín básico y '
                'mantente hidratado.',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
