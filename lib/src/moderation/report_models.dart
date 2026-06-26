import 'package:cloud_firestore/cloud_firestore.dart';

enum ReportTargetType {
  user,
  profile,
  comment,
  image,
  catalogEntry,
  collectionEntry,
  accountDeletion,
}

enum ReportReason {
  spam,
  harassment,
  unsafeLink,
  copyright,
  wrongInformation,
  inappropriateImage,
  other,
}

enum ReportStatus {
  open,
  reviewing,
  resolved,
  dismissed,
}

class UserReport {
  UserReport({
    required this.id,
    required this.reporterId,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.status,
    DateTime? createdAt,
    this.details = '',
    this.targetText = '',
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String reporterId;
  final ReportTargetType targetType;
  final String targetId;
  final ReportReason reason;
  final ReportStatus status;
  final DateTime createdAt;
  final String details;
  final String targetText;

  Map<String, Object?> toMap() {
    return {
      'reporterId': reporterId,
      'targetType': targetType.name,
      'targetId': targetId,
      'reason': reason.name,
      'status': status.name,
      'details': details,
      'createdAt': createdAt.toIso8601String(),
      'targetText': targetText,
    };
  }

  factory UserReport.fromMap(String id, Map<String, Object?> map) {
    return UserReport(
      id: id,
      reporterId: map['reporterId'] as String? ?? '',
      targetType: _targetTypeFromName(map['targetType'] as String?),
      targetId: map['targetId'] as String? ?? '',
      reason: _reasonFromName(map['reason'] as String?),
      status: _statusFromName(map['status'] as String?),
      details: map['details'] as String? ?? '',
      createdAt: _dateFromMapValue(map['createdAt']),
      targetText: map['targetText'] as String? ?? '',
    );
  }
}

ReportTargetType _targetTypeFromName(String? name) {
  return ReportTargetType.values.firstWhere(
    (type) => type.name == name,
    orElse: () => ReportTargetType.catalogEntry,
  );
}

ReportReason _reasonFromName(String? name) {
  return ReportReason.values.firstWhere(
    (reason) => reason.name == name,
    orElse: () => ReportReason.other,
  );
}

ReportStatus _statusFromName(String? name) {
  return ReportStatus.values.firstWhere(
    (status) => status.name == name,
    orElse: () => ReportStatus.open,
  );
}

DateTime _dateFromMapValue(Object? value) {
  if (value is DateTime) {
    return value;
  }

  if (value is Timestamp) {
    return value.toDate();
  }

  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  return DateTime.fromMillisecondsSinceEpoch(0);
}
