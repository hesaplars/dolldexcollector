import 'package:cloud_firestore/cloud_firestore.dart';

enum AppNotificationType {
  comment,
  like,
  follow,
  friendRequest,
  message,
  moderation,
  pro,
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    this.deepLink = '',
    this.createdAt,
  });

  final String id;
  final String userId;
  final AppNotificationType type;
  final String title;
  final String body;
  final bool isRead;
  final String deepLink;
  final DateTime? createdAt;

  Map<String, Object?> toMap() {
    return {
      'userId': userId,
      'type': type.name,
      'title': title,
      'body': body,
      'isRead': isRead,
      'deepLink': deepLink,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory AppNotification.fromMap(String id, Map<String, Object?> map) {
    return AppNotification(
      id: id,
      userId: map['userId'] as String? ?? '',
      type: AppNotificationType.values.firstWhere(
        (type) => type.name == map['type'],
        orElse: () => AppNotificationType.comment,
      ),
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      isRead: map['isRead'] as bool? ?? false,
      deepLink: map['deepLink'] as String? ?? '',
      createdAt: _dateFromMapValue(map['createdAt']),
    );
  }
}

DateTime? _dateFromMapValue(Object? value) {
  if (value is DateTime) {
    return value;
  }

  if (value is Timestamp) {
    return value.toDate();
  }

  if (value is String) {
    return DateTime.tryParse(value);
  }

  return null;
}
