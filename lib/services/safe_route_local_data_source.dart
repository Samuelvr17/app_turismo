import '../models/safe_route.dart';
import 'storage_service.dart';

class SafeRouteLocalDataSource {
  SafeRouteLocalDataSource({StorageService? storage})
      : _storage = storage ?? StorageService.instance;

  final StorageService _storage;

  Future<List<SafeRoute>> loadRoutes() => _storage.loadSafeRoutes();
}