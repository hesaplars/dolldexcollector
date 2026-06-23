import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../users/user_models.dart';
import 'social_models.dart';
import '../catalog/catalog_models.dart';
import '../comments/comment_models.dart';
import '../core/replay_stream.dart';

bool _isFirebaseInitialized() {
  try {
    return Firebase.apps.isNotEmpty;
  } catch (_) {
    return false;
  }
}

class SocialRepository {
  SocialRepository({FirebaseFirestore? firestore}) : _firestore = firestore;

  final FirebaseFirestore? _firestore;
  ReplayStream<List<ChatMessage>>? _globalChatStream;
  final Map<String, ReplayStream<List<ChatMessage>>> _directMessagesCache = {};
  final Map<String, ReplayStream<List<ChatThread>>> _chatThreadsCache = {};

  FirebaseFirestore? get _db {
    if (!_isFirebaseInitialized()) {
      return null;
    }

    return _firestore ?? FirebaseFirestore.instance;
  }

  Future<List<AppUser>> searchUsers(String query) async {
    final db = _db;
    final normalized = query.trim().toLowerCase();
    if (db == null) {
      return const <AppUser>[];
    }

    final request = normalized.length < 2
        ? db.collection('users').orderBy('usernameLower').limit(20)
        : db
            .collection('users')
            .orderBy('usernameLower')
            .where('usernameLower', isGreaterThanOrEqualTo: normalized)
            .where('usernameLower', isLessThan: '$normalized\uf8ff')
            .limit(20);

    final snapshot = await request.get();

    return snapshot.docs
        .map((doc) => AppUser.fromMap(doc.id, doc.data()))
        .where((user) => user.username.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> sendFriendRequest({
    required String fromUserId,
    required String toUserId,
  }) async {
    final db = _db;
    if (db == null || fromUserId == toUserId) {
      return;
    }

    final id = _pairId(fromUserId, toUserId);
    await db.collection('friendRequests').doc(id).set({
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'memberIds': [fromUserId, toUserId],
      'status': FriendshipStatus.pending.name,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    try {
      final senderDoc = await db.collection('users').doc(fromUserId).get();
      final senderUsername =
          senderDoc.data()?['username'] as String? ?? 'Collector';
      await db.collection('notifications').add({
        'userId': toUserId,
        'type': 'friendRequest',
        'title': 'Arkadaşlık İsteği / Friend Request',
        'body': '@$senderUsername sana arkadaşlık isteği gönderdi!',
        'isRead': false,
        'deepLink': '/social',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> respondToFriendRequest({
    required String fromUserId,
    required String toUserId,
    required bool accept,
  }) async {
    final db = _db;
    if (db == null) return;

    final id = _pairId(fromUserId, toUserId);
    if (accept) {
      await db.collection('friendRequests').doc(id).update({
        'status': 'accepted',
        'memberIds': [fromUserId, toUserId],
        'updatedAt': FieldValue.serverTimestamp(),
      });

      try {
        final recipientDoc = await db.collection('users').doc(toUserId).get();
        final recipientUsername =
            recipientDoc.data()?['username'] as String? ?? 'Collector';
        await db.collection('notifications').add({
          'userId': fromUserId,
          'type': 'friendRequest',
          'title': 'Arkadaşlık İsteği Kabul Edildi / Friend Request Accepted',
          'body': '@$recipientUsername arkadaşlık isteğini kabul etti!',
          'isRead': false,
          'deepLink': '/social',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    } else {
      await db.collection('friendRequests').doc(id).delete();
    }
  }

  Future<void> removeFriend({
    required String userA,
    required String userB,
  }) async {
    final db = _db;
    if (db == null) return;

    final id = _pairId(userA, userB);
    await db.collection('friendRequests').doc(id).delete();
  }

  Stream<bool> watchIsFriend(String userA, String userB) {
    final db = _db;
    if (db == null) return Stream.value(false);

    final id = _pairId(userA, userB);
    return db
        .collection('friendRequests')
        .doc(id)
        .snapshots()
        .map((snap) => snap.exists && snap.data()?['status'] == 'accepted');
  }

  Stream<bool> watchHasPendingRequest(String fromId, String toId) {
    final db = _db;
    if (db == null) return Stream.value(false);

    final id = _pairId(fromId, toId);
    return db
        .collection('friendRequests')
        .doc(id)
        .snapshots()
        .map((snap) => snap.exists && snap.data()?['status'] == 'pending');
  }

  Stream<List<Map<String, dynamic>>> watchFriendRequests(String userId) {
    final db = _db;
    if (db == null) return Stream.value([]);

    return db
        .collection('friendRequests')
        .where('toUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  Stream<List<FriendRequestWithUser>> watchIncomingRequestsWithUsers(
      String userId) {
    final db = _db;
    if (db == null || userId.isEmpty) return Stream.value([]);

    return watchFriendRequests(userId).asyncMap((requests) async {
      final List<FriendRequestWithUser> list = [];
      for (final req in requests) {
        final fromUserId = req['fromUserId'] as String? ?? '';
        if (fromUserId.isEmpty) continue;
        final userDoc = await db.collection('users').doc(fromUserId).get();
        if (userDoc.exists) {
          final sender = AppUser.fromMap(userDoc.id, userDoc.data() ?? {});
          list.add(FriendRequestWithUser(
            requestId: req['id'] as String,
            sender: sender,
            createdAt:
                (req['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          ));
        }
      }
      return list;
    });
  }

  Stream<List<String>> watchFriends(String userId) {
    final db = _db;
    if (db == null) return Stream.value([]);

    return db
        .collection('friendRequests')
        .where('status', isEqualTo: 'accepted')
        .where('memberIds', arrayContains: userId)
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) {
        final data = doc.data();
        final from = data['fromUserId'] as String? ?? '';
        final to = data['toUserId'] as String? ?? '';
        return from == userId ? to : from;
      }).toList();
    });
  }

  Future<void> blockUser({
    required String blockerId,
    required String blockedId,
  }) async {
    final db = _db;
    if (db == null || blockerId == blockedId) {
      return;
    }

    await db.collection('blocks').doc('$blockerId-$blockedId').set({
      'blockerId': blockerId,
      'blockedId': blockedId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unblockUser({
    required String blockerId,
    required String blockedId,
  }) async {
    final db = _db;
    if (db == null) return;

    await db.collection('blocks').doc('$blockerId-$blockedId').delete();
  }

  Stream<List<String>> watchBlockedUsers(String userId) {
    final db = _db;
    if (db == null) return Stream.value([]);

    return db
        .collection('blocks')
        .where('blockerId', isEqualTo: userId)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => doc.data()['blockedId'] as String).toList());
  }

  Future<String> openDirectThread({
    required String currentUserId,
    required String otherUserId,
  }) async {
    final db = _db;
    if (db == null || currentUserId == otherUserId) {
      return '';
    }

    final threadId = _pairId(currentUserId, otherUserId);
    await db.collection('chatThreads').doc(threadId).set({
      'memberIds': [currentUserId, otherUserId],
      'lastMessagePreview': '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return threadId;
  }

  Future<void> sendDirectMessage({
    required String threadId,
    required String senderId,
    required String text,
    String sharedCatalogId = '',
    String sharedCollectionId = '',
    String sharedCollectionStatus = '',
    String sharedSource = '',
  }) async {
    final db = _db;
    final trimmed = text.trim();
    if (db == null || threadId.isEmpty || (trimmed.isEmpty && sharedSource.isEmpty)) {
      return;
    }

    final userSnapshot = await db.collection('users').doc(senderId).get();
    final senderUsername =
        userSnapshot.data()?['username'] as String? ?? senderId;
    final senderAvatarId = userSnapshot.data()?['avatarId'] as String? ?? '';
    final senderFrameColor =
        userSnapshot.data()?['avatarFrameColor'] as String? ?? '';

    await db.collection('chatMessages').add({
      'threadId': threadId,
      'senderId': senderId,
      'senderUsername': senderUsername,
      'senderAvatarId': senderAvatarId,
      'senderFrameColor': senderFrameColor,
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
      'sharedCatalogId': sharedCatalogId,
      'sharedCollectionId': sharedCollectionId,
      'sharedCollectionStatus': sharedCollectionStatus,
      'sharedSource': sharedSource,
    });

    String preview = trimmed;
    if (preview.isEmpty && sharedSource.isNotEmpty) {
      preview = sharedSource == 'catalog'
          ? '🍼 Bir bebek paylaştı / Shared a doll'
          : '✨ Bir koleksiyon öğesi paylaştı / Shared a collection item';
    }

    await db.collection('chatThreads').doc(threadId).set({
      'lastMessagePreview': preview,
      'lastMessageSenderId': senderId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    try {
      final parts = threadId.split('-');
      final recipientId = parts.first == senderId ? parts.last : parts.first;
      await db.collection('notifications').add({
        'userId': recipientId,
        'type': 'message',
        'title': 'Yeni Mesaj / New Message',
        'body': '@$senderUsername: $preview',
        'isRead': false,
        'deepLink': '/social?chatUserId=$senderId',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Stream<List<ChatMessage>> watchDirectMessages(String threadId) {
    if (_directMessagesCache.containsKey(threadId)) {
      return _directMessagesCache[threadId]!;
    }

    final db = _db;
    if (db == null || threadId.isEmpty) {
      return const Stream<List<ChatMessage>>.empty();
    }

    final source = db
        .collection('chatMessages')
        .where('threadId', isEqualTo: threadId)
        .snapshots()
        .map(
      (snapshot) {
        final list = snapshot.docs
            .map((doc) => ChatMessage.fromMap(doc.id, doc.data()))
            .toList();
        list.sort((a, b) {
          final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });
        if (list.length > 60) {
          return list.sublist(0, 60);
        }
        return list;
      },
    );

    final stream = ReplayStream<List<ChatMessage>>(source);
    _directMessagesCache[threadId] = stream;
    return stream;
  }

  Stream<List<ChatThread>> watchChatThreads(String userId) {
    if (_chatThreadsCache.containsKey(userId)) {
      return _chatThreadsCache[userId]!;
    }

    final db = _db;
    if (db == null || userId.isEmpty) {
      return const Stream<List<ChatThread>>.empty();
    }

    final source = db
        .collection('chatThreads')
        .where('memberIds', arrayContains: userId)
        .snapshots()
        .map(
      (snapshot) {
        final list = snapshot.docs
            .map((doc) => ChatThread.fromMap(doc.id, doc.data()))
            .toList();
        list.sort((a, b) {
          final aTime = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });
        return list;
      },
    );

    final stream = ReplayStream<List<ChatThread>>(source);
    _chatThreadsCache[userId] = stream;
    return stream;
  }

  Future<void> deleteThreadForUser(String userId, String threadId) async {
    final db = _db;
    if (db == null || userId.isEmpty) return;
    await db.collection('deletedThreads').doc(userId).set({
      'threadIds': FieldValue.arrayUnion([threadId]),
    }, SetOptions(merge: true));
  }

  Stream<List<String>> watchDeletedThreads(String userId) {
    final db = _db;
    if (db == null || userId.isEmpty) {
      return Stream.value(const <String>[]);
    }
    return db.collection('deletedThreads').doc(userId).snapshots().map((doc) {
      if (!doc.exists) return const <String>[];
      final list = doc.data()?['threadIds'] as List? ?? [];
      return List<String>.from(list);
    });
  }

  Stream<List<ChatMessage>> watchGlobalChat() {
    if (_globalChatStream != null) {
      return _globalChatStream!;
    }

    final db = _db;
    if (db == null) {
      return const Stream<List<ChatMessage>>.empty();
    }

    final source = db
        .collection('globalChatMessages')
        .orderBy('createdAt', descending: true)
        .limit(60)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatMessage.fromMap(doc.id, doc.data()))
              .toList(growable: false),
        );

    _globalChatStream = ReplayStream<List<ChatMessage>>(source);
    return _globalChatStream!;
  }

  Future<void> sendGlobalMessage({
    required String senderId,
    required String text,
    String sharedCatalogId = '',
    String sharedCollectionId = '',
    String sharedCollectionStatus = '',
    String sharedSource = '',
  }) async {
    final db = _db;
    final trimmed = text.trim();
    if (db == null || (trimmed.isEmpty && sharedSource.isEmpty)) {
      return;
    }

    final userSnapshot = await db.collection('users').doc(senderId).get();
    final senderUsername =
        userSnapshot.data()?['username'] as String? ?? senderId;
    final senderAvatarId = userSnapshot.data()?['avatarId'] as String? ?? '';
    final senderFrameColor =
        userSnapshot.data()?['avatarFrameColor'] as String? ?? '';

    await db.collection('globalChatMessages').add({
      'senderId': senderId,
      'senderUsername': senderUsername,
      'senderAvatarId': senderAvatarId,
      'senderFrameColor': senderFrameColor,
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
      'sharedCatalogId': sharedCatalogId,
      'sharedCollectionId': sharedCollectionId,
      'sharedCollectionStatus': sharedCollectionStatus,
      'sharedSource': sharedSource,
    });
  }

  Future<void> likeTarget({
    required String userId,
    required String targetType,
    required String targetId,
  }) async {
    final db = _db;
    if (db == null || userId.isEmpty || targetId.isEmpty) {
      return;
    }

    await db.collection('likes').doc('$userId-$targetType-$targetId').set({
      'userId': userId,
      'targetType': targetType,
      'targetId': targetId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unlikeTarget({
    required String userId,
    required String targetType,
    required String targetId,
  }) async {
    final db = _db;
    if (db == null || userId.isEmpty || targetId.isEmpty) {
      return;
    }

    await db.collection('likes').doc('$userId-$targetType-$targetId').delete();
  }

  Stream<int> watchLikesCount(String targetType, String targetId) {
    final db = _db;
    if (db == null) {
      return Stream.value(0);
    }

    return db
        .collection('likes')
        .where('targetType', isEqualTo: targetType)
        .where('targetId', isEqualTo: targetId)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Stream<bool> watchIsLiked(String userId, String targetType, String targetId) {
    final db = _db;
    if (db == null || userId.isEmpty || targetId.isEmpty) {
      return Stream.value(false);
    }

    return db
        .collection('likes')
        .doc('$userId-$targetType-$targetId')
        .snapshots()
        .map((snap) => snap.exists);
  }

  Future<void> followUser({
    required String currentUserId,
    required String targetUserId,
  }) async {
    final db = _db;
    if (db == null ||
        currentUserId.isEmpty ||
        targetUserId.isEmpty ||
        currentUserId == targetUserId) {
      return;
    }

    await db.collection('follows').doc('$currentUserId-$targetUserId').set({
      'followerId': currentUserId,
      'followingId': targetUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unfollowUser({
    required String currentUserId,
    required String targetUserId,
  }) async {
    final db = _db;
    if (db == null || currentUserId.isEmpty || targetUserId.isEmpty) {
      return;
    }

    await db.collection('follows').doc('$currentUserId-$targetUserId').delete();
  }

  Stream<bool> watchIsFollowing(String currentUserId, String targetUserId) {
    final db = _db;
    if (db == null || currentUserId.isEmpty || targetUserId.isEmpty) {
      return Stream.value(false);
    }

    return db
        .collection('follows')
        .doc('$currentUserId-$targetUserId')
        .snapshots()
        .map((snap) => snap.exists);
  }

  Stream<List<AppUser>> watchFollowingList(String userId) {
    final db = _db;
    if (db == null || userId.isEmpty) {
      return Stream.value(const <AppUser>[]);
    }

    return db
        .collection('follows')
        .where('followerId', isEqualTo: userId)
        .snapshots()
        .asyncMap((snap) async {
      final uids =
          snap.docs.map((doc) => doc.data()['followingId'] as String).toList();
      if (uids.isEmpty) {
        return const <AppUser>[];
      }
      final List<AppUser> users = [];
      for (final uid in uids) {
        final userDoc = await db.collection('users').doc(uid).get();
        if (userDoc.exists) {
          users.add(AppUser.fromMap(userDoc.id, userDoc.data() ?? {}));
        }
      }
      return users;
    });
  }

  Stream<List<AppUser>> watchFollowersList(String userId) {
    final db = _db;
    if (db == null || userId.isEmpty) {
      return Stream.value(const <AppUser>[]);
    }

    return db
        .collection('follows')
        .where('followingId', isEqualTo: userId)
        .snapshots()
        .asyncMap((snap) async {
      final uids =
          snap.docs.map((doc) => doc.data()['followerId'] as String).toList();
      if (uids.isEmpty) {
        return const <AppUser>[];
      }
      final List<AppUser> users = [];
      for (final uid in uids) {
        final userDoc = await db.collection('users').doc(uid).get();
        if (userDoc.exists) {
          users.add(AppUser.fromMap(userDoc.id, userDoc.data() ?? {}));
        }
      }
      return users;
    });
  }

  Stream<List<AppUser>> watchFriendsList(String userId) {
    final db = _db;
    if (db == null || userId.isEmpty) {
      return Stream.value(const <AppUser>[]);
    }

    return watchFriends(userId).asyncMap((uids) async {
      if (uids.isEmpty) {
        return const <AppUser>[];
      }
      final List<AppUser> users = [];
      for (final uid in uids) {
        final userDoc = await db.collection('users').doc(uid).get();
        if (userDoc.exists) {
          users.add(AppUser.fromMap(userDoc.id, userDoc.data() ?? {}));
        }
      }
      return users;
    });
  }

  Stream<List<AppUser>> watchBlockedUsersList(String userId) {
    final db = _db;
    if (db == null || userId.isEmpty) {
      return Stream.value(const <AppUser>[]);
    }

    return watchBlockedUsers(userId).asyncMap((uids) async {
      if (uids.isEmpty) {
        return const <AppUser>[];
      }
      final List<AppUser> users = [];
      for (final uid in uids) {
        final userDoc = await db.collection('users').doc(uid).get();
        if (userDoc.exists) {
          users.add(AppUser.fromMap(userDoc.id, userDoc.data() ?? {}));
        }
      }
      return users;
    });
  }

  Stream<List<CollectionEntry>> watchRecentPublicCollectionEntries() {
    final db = _db;
    if (db == null) return Stream.value(const []);
    return db
        .collection('collectionEntries')
        .orderBy('updatedAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) {
              final data = doc.data();
              return CollectionEntry(
                id: doc.id,
                userId: data['userId'] as String? ?? '',
                itemId: data['itemId'] as String? ?? '',
                status: CollectionStatus.values.firstWhere(
                  (status) => status.name == data['status'],
                  orElse: () => CollectionStatus.owned,
                ),
                condition: CollectionCondition.values.firstWhere(
                  (condition) => condition.name == data['condition'],
                  orElse: () => CollectionCondition.complete,
                ),
                quantity: data['quantity'] as int? ?? 1,
                notes: data['notes'] as String? ?? '',
                isPublic: data['visibility'] != 'private',
                updatedAt: _dateFromValue(data['updatedAt']),
              );
            })
            .where((entry) => entry.isPublic)
            .take(45)
            .toList());
  }

  Stream<List<AppComment>> watchRecentComments() {
    final db = _db;
    if (db == null) return Stream.value(const []);
    return db
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .limit(45)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => AppComment.fromMap(doc.id, doc.data()))
            .toList());
  }

  DateTime? _dateFromValue(Object? value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _pairId(String first, String second) {
    final ids = [first, second]..sort();
    return '${ids.first}-${ids.last}';
  }
}
