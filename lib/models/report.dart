import 'package:flutter/foundation.dart';

@immutable
class Report {
  const Report({
    required this.id,
    required this.typeId,
    required this.description,
    required this.createdAt,
    this.latitude,
    this.longitude,
    this.isSynced = true,
    this.veredaName,
    this.userId,
  });

  final String id;
  final String typeId;
  final String description;
  final DateTime createdAt;
  final double? latitude;
  final double? longitude;
  final bool isSynced;
  final String? veredaName;
  final String? userId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'typeId': typeId,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'isSynced': isSynced,
      'veredaName': veredaName,
      'userId': userId,
    };
  }

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'] as String? ?? '',
      typeId: json['typeId'] as String? ?? ReportType.security.id,
      description: json['description'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      isSynced: json['isSynced'] as bool? ?? true,
      veredaName: json['veredaName'] as String?,
      userId: json['userId'] as String?,
    );
  }

  Report copyWith({
    String? id,
    String? typeId,
    String? description,
    DateTime? createdAt,
    double? latitude,
    double? longitude,
    bool? isSynced,
    String? veredaName,
    String? userId,
    bool resetLatitude = false,
    bool resetLongitude = false,
    bool resetVeredaName = false,
    bool resetUserId = false,
  }) {
    return Report(
      id: id ?? this.id,
      typeId: typeId ?? this.typeId,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      latitude: resetLatitude ? null : latitude ?? this.latitude,
      longitude: resetLongitude ? null : longitude ?? this.longitude,
      isSynced: isSynced ?? this.isSynced,
      veredaName: resetVeredaName ? null : veredaName ?? this.veredaName,
      userId: resetUserId ? null : userId ?? this.userId,
    );
  }
}

enum ReportType {
  security('security', 'Situación de seguridad'),
  infrastructure('infrastructure', 'Infraestructura urbana'),
  service('service', 'Servicio turístico'),
  other('other', 'Otro');

  const ReportType(this.id, this.label);

  final String id;
  final String label;

  static ReportType fromId(String? id) {
    if (id == null || id.isEmpty) {
      return ReportType.security;
    }

    return ReportType.values.firstWhere(
      (ReportType type) => type.id == id,
      orElse: () => ReportType.security,
    );
  }
}

extension ReportTypeExtension on ReportType {
  String get storageKey => id;
}