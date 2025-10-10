import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:panorama/panorama.dart';

import 'models/app_user.dart';
import 'models/report.dart';
import 'models/safe_route.dart';
import 'models/user_preferences.dart';
import 'models/weather_data.dart';
import 'services/location_service.dart';
import 'services/safe_route_local_data_source.dart';
import 'services/weather_service.dart';
import 'services/supabase_service.dart';
import 'services/storage_service.dart';
import 'services/auth_service.dart';
import 'widgets/login_page.dart';
import 'widgets/weather_card.dart';
import 'widgets/ar_danger_zone_view.dart';
import 'models/danger_zone.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await SupabaseService.instance.initialize();
  await AuthService.instance.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Turismo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthService _authService = AuthService.instance;
  AppUser? _lastUser;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppUser?>(
      valueListenable: _authService.currentUserListenable,
      builder: (BuildContext context, AppUser? user, _) {
        if (user == null) {
          if (_lastUser != null) {
            _lastUser = null;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              unawaited(StorageService.instance.clearForSignOut());
            });
          }
          return const LoginPage();
        }

        if (_lastUser?.id != user.id) {
          _lastUser = user;
        }

        return AuthenticatedApp(user: user);
      },
    );
  }
}

class AuthenticatedApp extends StatefulWidget {
  const AuthenticatedApp({
    super.key,
    required this.user,
  });

  final AppUser user;

  @override
  State<AuthenticatedApp> createState() => _AuthenticatedAppState();
}

class _AuthenticatedAppState extends State<AuthenticatedApp> {
  late Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization =
        StorageService.instance.initializeForUser(widget.user.id);
  }

  @override
  void didUpdateWidget(covariant AuthenticatedApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id) {
      setState(() {
        _initialization =
            StorageService.instance.initializeForUser(widget.user.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      'No se pudieron cargar tus datos. Intenta nuevamente.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _initialization = StorageService.instance
                              .initializeForUser(widget.user.id);
                        });
                      },
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return MainScaffold(
          onLogout: AuthService.instance.logout,
        );
      },
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({
    super.key,
    this.onLogout,
  });

  final VoidCallback? onLogout;

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;
  late final List<Widget> _tabPages;
  late final List<BottomNavigationBarItem> _navigationItems;
  final PageStorageBucket _pageStorageBucket = PageStorageBucket();

  static const List<_NavigationTab> _tabs = <_NavigationTab>[
    _NavigationTab(
      label: 'Mapa',
      icon: Icons.map,
      page: MapaPage(
        key: PageStorageKey<String>('MapaPage'),
      ),
    ),
    _NavigationTab(
      label: 'Rutas Seguras',
      icon: Icons.route,
      page: RutasSegurasPage(
        key: PageStorageKey<String>('RutasSegurasPage'),
      ),
    ),
    _NavigationTab(
      label: 'Reportes',
      icon: Icons.report,
      page: ReportesPage(
        key: PageStorageKey<String>('ReportesPage'),
      ),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabPages =
        _tabs.map((tab) => tab.page).toList(growable: false);
    _navigationItems = _tabs
        .map(
          (tab) => BottomNavigationBarItem(
            icon: Icon(tab.icon),
            label: tab.label,
          ),
        )
        .toList(growable: false);
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final _NavigationTab currentTab = _tabs[_selectedIndex];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(currentTab.label),
        actions: <Widget>[
          if (widget.onLogout != null)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Cerrar sesión',
              onPressed: widget.onLogout,
            ),
        ],
      ),
      body: PageStorage(
        bucket: _pageStorageBucket,
        child: IndexedStack(
          index: _selectedIndex,
          children: _tabPages,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: _navigationItems,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

class _NavigationTab {
  const _NavigationTab({
    required this.label,
    required this.icon,
    required this.page,
  });

  final String label;
  final IconData icon;
  final Widget page;
}

class MapaPage extends StatefulWidget {
  const MapaPage({super.key});

  @override
  State<MapaPage> createState() => _MapaPageState();
}

class _MapaPageState extends State<MapaPage> {
  static const List<DangerZone> _dangerZones = [
    DangerZone(
      id: 'centro_historico_villavicencio',
      center: LatLng(4.1161999958575795, -73.6088337333233),
      title: 'Centro histórico de Villavicencio',
      description:
          'Corredor comercial y peatonal con alta afluencia de visitantes, entidades financieras y comercio informal.',
      specificDangers:
          'Se reportan hurtos menores a transeúntes, motociclistas que irrumpen en las zonas peatonales y acumulación de puestos ambulantes que obstaculizan los puntos de evacuación al final de la tarde.',
      securityRecommendations:
          'Mantén tus objetos de valor seguros, evita manipular dinero en vía pública, recorre rutas iluminadas después del anochecer y coordina puntos de encuentro en lugares vigilados.',
      radius: 120,
      overlayHeight: 18,
    ),
    DangerZone(
      id: 'terminal_transporte_villavicencio',
      center: LatLng(4.110716544734726, -73.62999691007467),
      title: 'Terminal de Transporte de Villavicencio',
      description:
          'Nodo de conexión intermunicipal con flujo constante de pasajeros, vendedores informales y parqueaderos improvisados.',
      specificDangers:
          'Ocurren robos de equipaje durante el abordaje, ofertas de transporte no autorizado y maniobras continuas de buses y camiones en las bahías de espera.',
      securityRecommendations:
          'Compra tus tiquetes únicamente en puntos oficiales, permanece en áreas iluminadas mientras esperas, vigila tu equipaje en todo momento y utiliza servicios de transporte autorizados para tus desplazamientos.',
      radius: 150,
      overlayHeight: 22,
    ),
  ];

  final LocationService _locationService = LocationService.instance;
  late final VoidCallback _locationListener;
  GoogleMapController? _mapController;
  Position? _currentPosition;
  Marker? _userMarker;
  bool _isLoading = true;
  String? _errorMessage;
  String? _activeZoneId;
  bool _isShowingDialog = false;

  @override
  void initState() {
    super.initState();
    _locationListener = () {
      _handleLocationUpdate(_locationService.state);
    };

    final LocationState initialState = _locationService.state;
    _isLoading = initialState.isLoading;
    _errorMessage = initialState.errorMessage;
    _currentPosition = initialState.position;
    _userMarker = initialState.position != null
        ? _buildUserMarker(initialState.position!)
        : null;

    final Position? initialPosition = initialState.position;
    if (initialPosition != null) {
      unawaited(_moveCameraToPosition(initialPosition));
      unawaited(_evaluateDangerZones(initialPosition));
    }

    _locationService.stateListenable.addListener(_locationListener);
    unawaited(_locationService.initialize());
  }

  @override
  void dispose() {
    _locationService.stateListenable.removeListener(_locationListener);
    _mapController?.dispose();
    super.dispose();
  }

  void _handleLocationUpdate(LocationState state) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = state.isLoading;
      _errorMessage = state.errorMessage;
      _currentPosition = state.position;
      _userMarker = state.position != null
          ? _buildUserMarker(state.position!)
          : null;
    });

    final Position? position = state.position;
    if (position != null) {
      unawaited(_moveCameraToPosition(position));
      unawaited(_evaluateDangerZones(position));
    }
  }

  Future<void> _requestLocationRefresh() => _locationService.refresh();

  Future<void> _moveCameraToPosition(Position position) async {
    final controller = _mapController;
    if (controller == null) {
      return;
    }

    final target = LatLng(position.latitude, position.longitude);
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: 17),
      ),
    );
  }

  Marker _buildUserMarker(Position position) {
    return Marker(
      markerId: const MarkerId('user_location'),
      position: LatLng(position.latitude, position.longitude),
      infoWindow: const InfoWindow(title: 'Tu ubicación'),
    );
  }

  Future<void> _evaluateDangerZones(Position position) async {
    final zone = _findDangerZone(position);

    if (zone == null) {
      if (_activeZoneId != null && mounted) {
        setState(() {
          _activeZoneId = null;
        });
      }
      return;
    }

    if (_activeZoneId == zone.id) {
      return;
    }

    if (mounted) {
      setState(() {
        _activeZoneId = zone.id;
      });
    } else {
      _activeZoneId = zone.id;
    }

    await _showDangerDialog(zone);
  }

  DangerZone? _findDangerZone(Position position) {
    for (final zone in _dangerZones) {
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        zone.center.latitude,
        zone.center.longitude,
      );

      if (distance <= zone.radius) {
        return zone;
      }
    }
    return null;
  }

  Set<String> _collectNearbyZoneIds(Position position) {
    final Set<String> ids = <String>{};
    for (final zone in _dangerZones) {
      final double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        zone.center.latitude,
        zone.center.longitude,
      );

      if (distance <= zone.radius) {
        ids.add(zone.id);
      }
    }
    return ids;
  }

  Future<void> _openArDangerView() async {
    final Position? position = _currentPosition;
    if (position == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Activa la ubicación para abrir la vista de realidad aumentada.'),
        ),
      );
      return;
    }

    final Set<String> activeZones = _collectNearbyZoneIds(position);

    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ArDangerZoneView(
          dangerZones: _dangerZones,
          currentPosition: position,
          activeZoneIds: activeZones,
        ),
      ),
    );
  }

  Future<void> _showDangerDialog(DangerZone zone) async {
    if (_isShowingDialog || !mounted) {
      return;
    }

    _isShowingDialog = true;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('⚠️ Zona de Precaución'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  zone.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(zone.description),
                const SizedBox(height: 12),
                Text(
                  'Peligros específicos del área',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(zone.specificDangers),
                const SizedBox(height: 12),
                Text(
                  'Recomendaciones de seguridad',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(zone.securityRecommendations),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (Navigator.of(dialogContext).canPop()) {
                    Navigator.of(dialogContext).pop();
                  }
                },
                child: const Text('Entendido'),
              ),
            ],
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _isShowingDialog = false;
        });
      } else {
        _isShowingDialog = false;
      }
    }
  }

  Set<Circle> get _dangerZoneCircles {
    return _dangerZones
        .map(
          (zone) => Circle(
            circleId: CircleId(zone.id),
            center: zone.center,
            radius: zone.radius,
            fillColor: Colors.red.withAlpha(51),
            strokeColor: Colors.red.withAlpha(128),
            strokeWidth: 2,
          ),
        )
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (_isLoading) {
      body = const Center(
        child: CircularProgressIndicator(),
      );
    } else if (_errorMessage != null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_off,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => unawaited(_requestLocationRefresh()),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    } else {
      final initialTarget = _currentPosition != null
          ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
          : _dangerZones.first.center;

      body = GoogleMap(
        initialCameraPosition: CameraPosition(target: initialTarget, zoom: 16),
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        compassEnabled: true,
        circles: _dangerZoneCircles,
        markers: {
          if (_userMarker != null) _userMarker!,
        },
        onMapCreated: (controller) {
          _mapController = controller;
          final position = _currentPosition;
          if (position != null) {
            _moveCameraToPosition(position);
          }
        },
      );
    }

    final bool canOpenAr = !_isLoading && _errorMessage == null;

    return Stack(
      children: [
        Positioned.fill(child: body),
        if (canOpenAr)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.extended(
              onPressed: _openArDangerView,
              icon: const Icon(Icons.view_in_ar),
              label: const Text('Ver en AR'),
            ),
          ),
      ],
    );
  }
}

class RutasSegurasPage extends StatefulWidget {
  const RutasSegurasPage({super.key});

  @override
  State<RutasSegurasPage> createState() => _RutasSegurasPageState();
}

class _RutasSegurasPageState extends State<RutasSegurasPage> {
  static const List<SafeRoute> _defaultRoutes = <SafeRoute>[
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
  ];

  static const LatLng _veredaBuenavistaLocation =
      LatLng(4.157296670026874, -73.68158509824853);

  static const Map<String, List<String>> _activityImages =
      <String, List<String>>{
    'Miradores': <String>[
      'https://images.unsplash.com/photo-1491557345352-5929e343eb89?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1454496522488-7a8e488e8606?auto=format&fit=crop&w=1200&q=80',
    ],
    'Parapente': <String>[
      'assets/images/parapente/parapente_360.jpg',
    ],
    'Caminata ecológica': <String>[
      'https://images.unsplash.com/photo-1470246973918-29a93221c455?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?auto=format&fit=crop&w=1200&q=80',
    ],
  };

  static const Set<String> _panoramicImageAssets = <String>{
    'assets/images/parapente/parapente_360.jpg',
  };

  final SafeRouteLocalDataSource _localDataSource = SafeRouteLocalDataSource();
  List<SafeRoute> _routes = const <SafeRoute>[];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeRoutes();
  }

  Future<void> _initializeRoutes() async {
    try {
      final List<SafeRoute> routes = await _localDataSource.loadRoutes();

      if (!mounted) {
        return;
      }

      if (routes.isEmpty) {
        await _localDataSource.saveRoutes(_defaultRoutes);

        if (!mounted) {
          return;
        }

        setState(() {
          _routes = _defaultRoutes;
          _isLoading = false;
        });
      } else {
        setState(() {
          _routes = routes;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _routes = _defaultRoutes;
        _isLoading = false;
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

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _routes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
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
    );
  }

  void _openActivityDetail({
    required SafeRoute route,
    required String activity,
  }) {
    final List<String> imageUrls =
        _activityImages[activity] ?? const <String>[];
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => SafeRouteActivityDetailPage(
          routeName: route.name,
          activityName: activity,
          routeDescription: route.description,
          location: _veredaBuenavistaLocation,
          imageUrls: imageUrls,
          panoramicImagePaths: _panoramicImageAssets,
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
    this.panoramicImagePaths,
  });

  final String routeName;
  final String activityName;
  final String routeDescription;
  final LatLng location;
  final List<String> imageUrls;
  final Set<String>? panoramicImagePaths;

  @override
  State<SafeRouteActivityDetailPage> createState() => _SafeRouteActivityDetailPageState();
}

class _SafeRouteActivityDetailPageState extends State<SafeRouteActivityDetailPage> {
  final WeatherService _weatherService = WeatherService.instance;
  WeatherData? _weatherData;
  bool _isLoadingWeather = true;
  String? _weatherError;
  VoidCallback? _weatherListener;
  late final bool _shouldShowWeather;
  late final PageController _pageController;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _shouldShowWeather =
        widget.activityName.toLowerCase().contains('parapente');

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
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () => _showFullScreenImage(imageUrl),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _buildImageWidget(imageUrl),
                  ),
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
    final bool isPanoramicImage = _isPanoramicImage(imageUrl);

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

    if (isPanoramicImage) {
      return Panorama(
        sensorControl: SensorControl.Orientation,
        child: Image.asset(
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
        ),
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
    final bool isPanoramicImage = _isPanoramicImage(imageUrl);

    Widget _buildFullScreenContent() {
      if (isPanoramicImage) {
        return Panorama(
          sensorControl: SensorControl.Orientation,
          child: Image.asset(
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
          ),
        );
      }

      if (isNetworkImage) {
        return Image.network(imageUrl, fit: BoxFit.contain);
      }

      return Image.asset(imageUrl, fit: BoxFit.contain);
    }

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (BuildContext context) {
        return GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            color: Colors.black,
            alignment: Alignment.center,
            child: isPanoramicImage
                ? _buildFullScreenContent()
                : InteractiveViewer(child: _buildFullScreenContent()),
          ),
        );
      },
    );
  }

  bool _isPanoramicImage(String imageUrl) {
    final Set<String>? panoramicPaths = widget.panoramicImagePaths;
    if (panoramicPaths == null || panoramicPaths.isEmpty) {
      return false;
    }
    return panoramicPaths.contains(imageUrl);
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
                        .withOpacity(0.8),
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
              ..._safetyConsiderations
                  .map(
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
                  )
                  .toList(growable: false),
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

class ReportesPage extends StatefulWidget {
  const ReportesPage({super.key});

  @override
  State<ReportesPage> createState() => _ReportesPageState();
}

class _ReportesPageState extends State<ReportesPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  final StorageService _storageService = StorageService.instance;
  final LocationService _locationService = LocationService.instance;

  late final VoidCallback _preferencesListener;
  late final VoidCallback _locationListener;

  ReportType? _selectedType;
  bool _shareLocation = true;
  bool _isSubmitting = false;
  LocationState _locationState = const LocationState();

  @override
  void initState() {
    super.initState();

    final UserPreferences initialPreferences = _storageService.preferences;
    final String? preferredTypeId = initialPreferences.preferredReportTypeId;
    if (preferredTypeId != null && preferredTypeId.isNotEmpty) {
      _selectedType = ReportType.fromId(preferredTypeId);
    }
    _shareLocation = initialPreferences.shareLocation;
    _locationState = _locationService.state;

    _preferencesListener = () {
      if (!mounted) {
        return;
      }

      final UserPreferences prefs = _storageService.preferences;
      setState(() {
        _shareLocation = prefs.shareLocation;
        final String? storedTypeId = prefs.preferredReportTypeId;
        if (storedTypeId != null && storedTypeId.isNotEmpty) {
          _selectedType = ReportType.fromId(storedTypeId);
        }
      });
    };

    _locationListener = () {
      if (!mounted) {
        return;
      }

      setState(() {
        _locationState = _locationService.state;
      });
    };

    _storageService.preferencesListenable.addListener(_preferencesListener);
    _locationService.stateListenable.addListener(_locationListener);
    unawaited(_locationService.initialize());
  }

  @override
  void dispose() {
    _storageService.preferencesListenable.removeListener(_preferencesListener);
    _locationService.stateListenable.removeListener(_locationListener);
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildForm(context),
          const SizedBox(height: 24),
          ValueListenableBuilder<List<Report>>(
            valueListenable: _storageService.reportsListenable,
            builder: (BuildContext context, List<Report> reports, _) {
              return _buildReportsSection(context, reports);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Nuevo reporte',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ReportType>(
            initialValue: _selectedType,
            decoration: const InputDecoration(
              labelText: 'Tipo de reporte',
              border: OutlineInputBorder(),
            ),
            validator: (ReportType? value) {
              if (value == null) {
                return 'Selecciona el tipo de reporte';
              }
              return null;
            },
            items: ReportType.values
                .map(
                  (ReportType type) => DropdownMenuItem<ReportType>(
                    value: type,
                    child: Text(type.label),
                  ),
                )
                .toList(growable: false),
            onChanged: (ReportType? value) {
              setState(() {
                _selectedType = value;
              });

              if (value != null) {
                final ScaffoldMessengerState messenger =
                    ScaffoldMessenger.of(context);
                final UserPreferences currentPreferences =
                    _storageService.preferences.copyWith(
                  preferredReportTypeId: value.id,
                );
                unawaited(
                  _storageService.saveUserPreferences(currentPreferences).catchError(
                    (Object error) {
                      if (!mounted) {
                        return;
                      }
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            'No se pudieron sincronizar las preferencias: $error',
                          ),
                        ),
                      );
                    },
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            minLines: 3,
            maxLines: 5,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              labelText: 'Describe lo ocurrido',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            validator: (String? value) {
              if (value == null || value.trim().isEmpty) {
                return 'La descripción es obligatoria';
              }

              if (value.trim().length < 10) {
                return 'Describe lo sucedido con al menos 10 caracteres';
              }

              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildLocationIndicator(context),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Compartir ubicación en mis reportes'),
            subtitle: Text(
              _shareLocation
                  ? 'La latitud y longitud se guardarán junto al reporte.'
                  : 'Solo se almacenará el texto del reporte.',
            ),
            value: _shareLocation,
            onChanged: (bool value) {
              setState(() {
                _shareLocation = value;
              });

              final ScaffoldMessengerState messenger =
                  ScaffoldMessenger.of(context);
              final UserPreferences currentPreferences =
                  _storageService.preferences.copyWith(
                shareLocation: value,
              );
              unawaited(
                _storageService.saveUserPreferences(currentPreferences).catchError(
                  (Object error) {
                    if (!mounted) {
                      return;
                    }
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          'No se pudieron sincronizar las preferencias: $error',
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _isSubmitting ? null : _handleSubmit,
              icon: const Icon(Icons.send),
              label: Text(_isSubmitting ? 'Enviando...' : 'Enviar Reporte'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationIndicator(BuildContext context) {
    final LocationState state = _locationState;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    IconData icon;
    Color iconColor;
    Widget message;
    Widget? trailing;

    if (state.isLoading) {
      icon = Icons.my_location;
      iconColor = colorScheme.primary;
      message = const Text('Obteniendo ubicación actual...');
      trailing = const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (state.errorMessage != null) {
      icon = Icons.location_off_outlined;
      iconColor = colorScheme.error;
      message = Text(state.errorMessage!);
    } else if (state.position != null) {
      final Position position = state.position!;
      icon = Icons.place_outlined;
      iconColor = colorScheme.primary;
      final String coordinates =
          'Lat: ${position.latitude.toStringAsFixed(5)}, Lng: ${position.longitude.toStringAsFixed(5)}';
      message = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(coordinates),
          const SizedBox(height: 4),
          Text(
            _shareLocation
                ? 'La ubicación se incluirá en el reporte.'
                : 'Has elegido no compartir la ubicación en este reporte.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    } else {
      icon = Icons.location_searching;
      iconColor = colorScheme.secondary;
      message = const Text('Ubicación no disponible en este momento.');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest
            .withAlpha((0.6 * 255).round()),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(child: message),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: 12),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _buildReportsSection(BuildContext context, List<Report> reports) {
    final ThemeData theme = Theme.of(context);

    if (reports.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Reportes sincronizados',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Aún no has registrado reportes en la nube. Completa el formulario para crear el primero.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Reportes sincronizados',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        ...List<Widget>.generate(reports.length, (int index) {
          final Report report = reports[index];
          return Padding(
            padding: EdgeInsets.only(bottom: index == reports.length - 1 ? 0 : 12),
            child: _buildReportCard(context, report),
          );
        }),
      ],
    );
  }

  Widget _buildReportCard(BuildContext context, Report report) {
    final ThemeData theme = Theme.of(context);
    final ReportType type = ReportType.fromId(report.typeId);
    final String formattedDate = _formatDate(report.createdAt);
    final bool hasLocation =
        report.latitude != null && report.longitude != null;
    final String locationText = hasLocation
        ? 'Lat: ${report.latitude!.toStringAsFixed(4)}, Lng: ${report.longitude!.toStringAsFixed(4)}'
        : 'Este reporte se guardó sin coordenadas.';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        type.label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formattedDate,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Eliminar reporte',
                  onPressed: () => unawaited(_removeReport(report)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              report.description,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: hasLocation
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    locationText,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleSubmit() {
    if (_isSubmitting) {
      return;
    }
    unawaited(_submitReport());
  }

  Future<void> _submitReport() async {
    final FormState? formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    final ReportType? selectedType = _selectedType;
    if (selectedType == null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    FocusScope.of(context).unfocus();

    final Position? position = _locationState.position;
    final double? latitude =
        _shareLocation && position != null ? position.latitude : null;
    final double? longitude =
        _shareLocation && position != null ? position.longitude : null;

    try {
      await _storageService.saveReport(
        type: selectedType,
        description: _descriptionController.text.trim(),
        latitude: latitude,
        longitude: longitude,
      );

      final UserPreferences updatedPreferences =
          _storageService.preferences.copyWith(
        preferredReportTypeId: selectedType.id,
        shareLocation: _shareLocation,
      );
      await _storageService.saveUserPreferences(updatedPreferences);

      if (!mounted) {
        return;
      }

      _descriptionController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reporte sincronizado en la nube.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo sincronizar el reporte: $error'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      } else {
        _isSubmitting = false;
      }
    }
  }

  Future<void> _removeReport(Report report) async {
    try {
      await _storageService.deleteReport(report.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reporte eliminado de la nube.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo eliminar el reporte remoto: $error'),
          ),
        );
      }
    }
  }

  String _formatDate(DateTime dateTime) {
    final DateTime local = dateTime.toLocal();
    final String day = local.day.toString().padLeft(2, '0');
    final String month = local.month.toString().padLeft(2, '0');
    final String year = local.year.toString();
    final String hour = local.hour.toString().padLeft(2, '0');
    final String minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }
}