import '../models/report.dart';
import '../models/safe_route.dart';
import '../models/user_preferences.dart';

abstract class ReportsRemoteDataSource {
  Future<Report> saveReport({
    required ReportType type,
    required String description,
    double? latitude,
    double? longitude,
  });

  Future<List<Report>> getReports();

  Future<void> deleteReport(String id);

  Future<void> saveUserPreferences(UserPreferences preferences);

  Future<UserPreferences?> getUserPreferences();

  Future<void> saveSafeRoutes(List<SafeRoute> routes);

  Future<List<SafeRoute>> getSafeRoutes();
}
