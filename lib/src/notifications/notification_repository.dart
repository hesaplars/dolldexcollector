import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import 'notification_models.dart';
import '../core/replay_stream.dart';

abstract class NotificationRepository {
  Stream<List<AppNotification>> watchForUser(String userId);

  Future<void> markRead(String notificationId);

  Future<void> markAllRead(String userId);

  Future<void> delete(String notificationId);

  Future<void> publishAnnouncement(String title, String body);

  Future<void> deleteAnnouncement(String deepLink);

  Future<void> sendCustomNotification({
    required String userId,
    required String title,
    required String body,
  });
}

bool _isFirebaseInitialized() {
  try {
    return Firebase.apps.isNotEmpty;
  } catch (_) {
    return false;
  }
}

class FirestoreNotificationRepository implements NotificationRepository {
  FirestoreNotificationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;
  final List<AppNotification> _notifications = [];
  final StreamController<List<AppNotification>> _controller =
      StreamController<List<AppNotification>>.broadcast();
  final Map<String, ReplayStream<List<AppNotification>>> _watchCache = {};

  FirebaseFirestore? get _db {
    if (!_isFirebaseInitialized()) {
      return null;
    }

    return _firestore ?? FirebaseFirestore.instance;
  }

  @override
  Stream<List<AppNotification>> watchForUser(String userId) {
    if (_watchCache.containsKey(userId)) {
      return _watchCache[userId]!;
    }

    final db = _db;
    late Stream<List<AppNotification>> source;

    if (db != null && userId != 'local-user') {
      source = db
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => AppNotification.fromMap(doc.id, doc.data()))
                .toList()
              ..sort(
                (a, b) => _notificationCreatedAt(b).compareTo(
                  _notificationCreatedAt(a),
                ),
              ),
          )
          .handleError((_) {});
    } else {
      final localController = StreamController<List<AppNotification>>();
      localController.add(_forUser(userId));
      final sub = _controller.stream.listen((_) {
        if (!localController.isClosed) {
          localController.add(_forUser(userId));
        }
      });
      localController.onCancel = () {
        sub.cancel();
        localController.close();
      };
      source = localController.stream;
    }

    final stream = ReplayStream<List<AppNotification>>(source);
    _watchCache[userId] = stream;
    return stream;
  }

  @override
  Future<void> markRead(String notificationId) async {
    final db = _db;
    if (db != null) {
      await db.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });
      return;
    }

    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      final n = _notifications[index];
      _notifications[index] = AppNotification(
        id: n.id,
        userId: n.userId,
        type: n.type,
        title: n.title,
        body: n.body,
        isRead: true,
        deepLink: n.deepLink,
        createdAt: n.createdAt,
      );
    }
    _controller.add(_notifications);
  }

  @override
  Future<void> markAllRead(String userId) async {
    final db = _db;
    if (db != null && userId != 'local-user') {
      final snapshot = await db
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = db.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
      return;
    }

    for (var i = 0; i < _notifications.length; i++) {
      final n = _notifications[i];
      if (n.userId == userId) {
        _notifications[i] = AppNotification(
          id: n.id,
          userId: n.userId,
          type: n.type,
          title: n.title,
          body: n.body,
          isRead: true,
          deepLink: n.deepLink,
          createdAt: n.createdAt,
        );
      }
    }
    _controller.add(_notifications);
  }

  @override
  Future<void> delete(String notificationId) async {
    final db = _db;
    if (db != null) {
      await db.collection('notifications').doc(notificationId).delete();
      return;
    }

    _notifications.removeWhere((n) => n.id == notificationId);
    _controller.add(_notifications);
  }

  @override
  Future<void> deleteAnnouncement(String deepLink) async {
    final db = _db;
    if (db != null) {
      final snapshot = await db
          .collection('notifications')
          .where('deepLink', isEqualTo: deepLink)
          .get();

      final batch = db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      return;
    }

    _notifications.removeWhere((n) => n.deepLink == deepLink);
    _controller.add(_notifications);
  }

  @override
  Future<void> publishAnnouncement(String title, String body) async {
    final db = _db;
    final deepLink =
        '/announcement?title=${Uri.encodeComponent(title)}&body=${Uri.encodeComponent(body)}';

    if (db != null) {
      final usersSnapshot = await db.collection('users').get();
      final batch = db.batch();
      for (final userDoc in usersSnapshot.docs) {
        final docRef = db.collection('notifications').doc();
        batch.set(docRef, {
          'userId': userDoc.id,
          'type': 'pro',
          'title': title,
          'body': body,
          'isRead': false,
          'deepLink': deepLink,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      return;
    }

    final localNotif = AppNotification(
      id: 'announcement-${DateTime.now().millisecondsSinceEpoch}',
      userId: 'local-user',
      type: AppNotificationType.pro,
      title: title,
      body: body,
      isRead: false,
      deepLink: deepLink,
      createdAt: DateTime.now(),
    );
    _notifications.add(localNotif);
    _controller.add(_notifications);
  }

  @override
  Future<void> sendCustomNotification({
    required String userId,
    required String title,
    required String body,
  }) async {
    final db = _db;
    if (db != null) {
      await db.collection('notifications').add({
        'userId': userId,
        'type': 'moderation',
        'title': title,
        'body': body,
        'isRead': false,
        'deepLink': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    final localNotif = AppNotification(
      id: 'custom-${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      type: AppNotificationType.moderation,
      title: title,
      body: body,
      isRead: false,
      deepLink: '',
      createdAt: DateTime.now(),
    );
    _notifications.add(localNotif);
    _controller.add(_notifications);
  }

  List<AppNotification> _forUser(String userId) {
    return _notifications
        .where((notification) => notification.userId == userId)
        .toList(growable: false);
  }
}

DateTime _notificationCreatedAt(AppNotification notification) {
  return notification.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
}
