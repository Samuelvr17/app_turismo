import '../models/report.dart';
import '../models/safe_route.dart';
import '../models/user_preferences.dart';

abstract class ReportsRemoteDataSource {
  Future<Report> saveReport({
    required String userId,
    required ReportType type,
    required String description,
    double? latitude,
    double? longitude,
  });

  Future<List<Report>> getReports({required String userId});

  Future<void> deleteReport({
    required String id,
    required String userId,
  });

  Future<void> saveUserPreferences({
    required String userId,
    required UserPreferences preferences,
  });

  Future<UserPreferences?> getUserPreferences({required String userId});

  Future<List<SafeRoute>> getSafeRoutes();
}
