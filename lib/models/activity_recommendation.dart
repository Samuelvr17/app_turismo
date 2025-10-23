import 'package:flutter/foundation.dart';

@immutable
class ActivityRecommendation {
  const ActivityRecommendation({
    required this.activityName,
    required this.summary,
    this.location,
    this.confidence,
    this.tags = const <String>[],
    required this.createdAt,
  });

  final String activityName;
  final String summary;
  final String? location;
  final double? confidence;
  final List<String> tags;
  final DateTime createdAt;

  ActivityRecommendation copyWith({
    String? activityName,
    String? summary,
    String? location,
    double? confidence,
    List<String>? tags,
    DateTime? createdAt,
  }) {
    return ActivityRecommendation(
      activityName: activityName ?? this.activityName,
      summary: summary ?? this.summary,
      location: location ?? this.location,
      confidence: confidence ?? this.confidence,
      tags: tags ?? List<String>.from(this.tags),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'activityName': activityName,
      'summary': summary,
      'location': location,
      'confidence': confidence,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ActivityRecommendation.fromJson(Map<String, dynamic> json) {
    final String? rawCreatedAt = json['createdAt'] as String?;
    final DateTime createdAt = rawCreatedAt != null
        ? DateTime.tryParse(rawCreatedAt) ?? DateTime.now()
        : DateTime.now();

    return ActivityRecommendation(
      activityName: json['activityName'] as String? ?? 'Actividad',
      summary: json['summary'] as String? ?? '',
      location: json['location'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
      tags: (json['tags'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic value) => value.toString())
          .toList(),
      createdAt: createdAt,
    );
  }
}
