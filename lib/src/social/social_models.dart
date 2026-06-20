import 'package:cloud_firestore/cloud_firestore.dart';
import '../users/user_models.dart';

enum FriendshipStatus {
  pending,
  accepted,
  declined,
  blocked,
}

class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.status,
  });

  final String id;
  final String fromUserId;
  final String toUserId;
  final FriendshipStatus status;

  Map<String, Object?> toMap() {
    return {
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'status': status.name,
    };
  }
}

class FollowRelation {
  const FollowRelation({
    required this.id,
    required this.followerId,
    required this.followingId,
  });

  final String id;
  final String followerId;
  final String followingId;

  Map<String, Object?> toMap() {
    return {
      'followerId': followerId,
      'followingId': followingId,
    };
  }
}

class ChatThread {
  const ChatThread({
    required this.id,
    required this.memberIds,
    required this.lastMessagePreview,
    this.lastMessageSenderId = '',
    this.updatedAt,
  });

  final String id;
  final List<String> memberIds;
  final String lastMessagePreview;
  final String lastMessageSenderId;
  final DateTime? updatedAt;

  Map<String, Object?> toMap() {
    return {
      'memberIds': memberIds,
      'lastMessagePreview': lastMessagePreview,
      'lastMessageSenderId': lastMessageSenderId,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory ChatThread.fromMap(String id, Map<String, Object?> map) {
    return ChatThread(
      id: id,
      memberIds: List<String>.from(map['memberIds'] as List? ?? []),
      lastMessagePreview: map['lastMessagePreview'] as String? ?? '',
      lastMessageSenderId: map['lastMessageSenderId'] as String? ?? '',
      updatedAt: _dateFromMapValue(map['updatedAt']),
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.text,
    this.senderUsername = '',
    this.senderAvatarId = '',
    this.senderFrameColor = '',
    this.createdAt,
  });

  final String id;
  final String threadId;
  final String senderId;
  final String text;
  final String senderUsername;
  final String senderAvatarId;
  final String senderFrameColor;
  final DateTime? createdAt;

  Map<String, Object?> toMap() {
    return {
      'threadId': threadId,
      'senderId': senderId,
      'text': text,
      'senderUsername': senderUsername,
      'senderAvatarId': senderAvatarId,
      'senderFrameColor': senderFrameColor,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory ChatMessage.fromMap(String id, Map<String, Object?> map) {
    return ChatMessage(
      id: id,
      threadId: map['threadId'] as String? ?? '',
      senderId: map['senderId'] as String? ?? '',
      text: map['text'] as String? ?? '',
      senderUsername: map['senderUsername'] as String? ?? '',
      senderAvatarId: map['senderAvatarId'] as String? ?? '',
      senderFrameColor: map['senderFrameColor'] as String? ?? '',
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

class FriendRequestWithUser {
  const FriendRequestWithUser({
    required this.requestId,
    required this.sender,
    required this.createdAt,
  });

  final String requestId;
  final AppUser sender;
  final DateTime createdAt;
}
