import 'package:flutter/foundation.dart';

@immutable
class ActivitySurvey {
  const ActivitySurvey({
    required this.travelStyle,
    required this.interests,
    required this.activityLevel,
    required this.travelCompanions,
    required this.budgetLevel,
    required this.preferredTimeOfDay,
    this.additionalNotes,
    this.completedAt,
  });

  final String travelStyle;
  final List<String> interests;
  final String activityLevel;
  final String travelCompanions;
  final String budgetLevel;
  final String preferredTimeOfDay;
  final String? additionalNotes;
  final DateTime? completedAt;

  static const ActivitySurvey defaults = ActivitySurvey(
    travelStyle: 'equilibrado',
    interests: <String>[],
    activityLevel: 'media',
    travelCompanions: 'solo',
    budgetLevel: 'moderado',
    preferredTimeOfDay: 'manana',
  );

  ActivitySurvey copyWith({
    String? travelStyle,
    List<String>? interests,
    String? activityLevel,
    String? travelCompanions,
    String? budgetLevel,
    String? preferredTimeOfDay,
    String? additionalNotes,
    DateTime? completedAt,
  }) {
    return ActivitySurvey(
      travelStyle: travelStyle ?? this.travelStyle,
      interests: interests ?? List<String>.from(this.interests),
      activityLevel: activityLevel ?? this.activityLevel,
      travelCompanions: travelCompanions ?? this.travelCompanions,
      budgetLevel: budgetLevel ?? this.budgetLevel,
      preferredTimeOfDay: preferredTimeOfDay ?? this.preferredTimeOfDay,
      additionalNotes: additionalNotes ?? this.additionalNotes,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'travelStyle': travelStyle,
      'interests': interests,
      'activityLevel': activityLevel,
      'travelCompanions': travelCompanions,
      'budgetLevel': budgetLevel,
      'preferredTimeOfDay': preferredTimeOfDay,
      'additionalNotes': additionalNotes,
      if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
    };
  }

  factory ActivitySurvey.fromJson(Map<String, dynamic> json) {
    return ActivitySurvey(
      travelStyle: json['travelStyle'] as String? ?? 'equilibrado',
      interests: (json['interests'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic value) => value.toString())
          .toList(),
      activityLevel: json['activityLevel'] as String? ?? 'media',
      travelCompanions: json['travelCompanions'] as String? ?? 'solo',
      budgetLevel: json['budgetLevel'] as String? ?? 'moderado',
      preferredTimeOfDay: json['preferredTimeOfDay'] as String? ?? 'manana',
      additionalNotes: json['additionalNotes'] as String?,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
    );
  }
}
