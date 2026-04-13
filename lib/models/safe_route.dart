import 'package:flutter/foundation.dart';

@immutable
class SafeRoute {
  const SafeRoute({
    required this.name,
    required this.duration,
    required this.difficulty,
    required this.description,
    required this.pointsOfInterest,
    this.pdfUrl,
  });

  final String name;
  final String duration;
  final String difficulty;
  final String description;
  final List<String> pointsOfInterest;
  final String? pdfUrl;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'duration': duration,
      'difficulty': difficulty,
      'description': description,
      'points_of_interest': pointsOfInterest,
      'pdf_url': pdfUrl,
    };
  }

  factory SafeRoute.fromJson(Map<String, dynamic> json) {
    return SafeRoute(
      name: json['name'] as String? ?? '',
      duration: json['duration'] as String? ?? '',
      difficulty: json['difficulty'] as String? ?? '',
      description: json['description'] as String? ?? '',
      pointsOfInterest: (json['points_of_interest'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic item) => item.toString())
          .toList(growable: false),
      pdfUrl: json['pdf_url'] as String?,
    );
  }
}