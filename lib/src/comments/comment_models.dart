import 'package:cloud_firestore/cloud_firestore.dart';

class AppComment {
  AppComment({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.userId,
    required this.text,
    DateTime? createdAt,
    this.sharedCatalogEntryId = '',
    this.senderUsername = '',
    this.senderAvatarId = '',
    this.senderFrameColor = '',
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String targetType;
  final String targetId;
  final String userId;
  final String text;
  final DateTime createdAt;
  final String sharedCatalogEntryId;
  final String senderUsername;
  final String senderAvatarId;
  final String senderFrameColor;

  Map<String, Object?> toMap() {
    return {
      'targetType': targetType,
      'targetId': targetId,
      'userId': userId,
      'text': text,
      'sharedCatalogEntryId': sharedCatalogEntryId,
      'createdAt': createdAt.toIso8601String(),
      'senderUsername': senderUsername,
      'senderAvatarId': senderAvatarId,
      'senderFrameColor': senderFrameColor,
    };
  }

  factory AppComment.fromMap(String id, Map<String, Object?> map) {
    return AppComment(
      id: id,
      targetType: map['targetType'] as String? ?? '',
      targetId: map['targetId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      text: map['text'] as String? ?? '',
      createdAt: _dateFromMapValue(map['createdAt']),
      sharedCatalogEntryId: map['sharedCatalogEntryId'] as String? ?? '',
      senderUsername: map['senderUsername'] as String? ?? '',
      senderAvatarId: map['senderAvatarId'] as String? ?? '',
      senderFrameColor: map['senderFrameColor'] as String? ?? '',
    );
  }
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
