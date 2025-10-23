import 'package:flutter/foundation.dart';

import 'safe_route.dart';

@immutable
class AvailableActivity {
  const AvailableActivity({
    required this.name,
    required this.routeName,
    required this.routeDescription,
    required this.routeDifficulty,
    this.tags = const <String>[],
  });

  final String name;
  final String routeName;
  final String routeDescription;
  final String routeDifficulty;
  final List<String> tags;

  factory AvailableActivity.fromSafeRoute(SafeRoute route, String activityName) {
    return AvailableActivity(
      name: activityName.trim(),
      routeName: route.name,
      routeDescription: route.description,
      routeDifficulty: route.difficulty,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'routeName': routeName,
      'routeDescription': routeDescription,
      'routeDifficulty': routeDifficulty,
      'tags': tags,
    };
  }
}
