import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import 'comment_models.dart';

abstract class CommentRepository {
  Stream<List<AppComment>> watchForTarget({
    required String targetType,
    required String targetId,
  });

  Future<void> add(AppComment comment);
  Future<void> delete(String commentId);
}

bool _isFirebaseInitialized() {
  try {
    return Firebase.apps.isNotEmpty;
  } catch (_) {
    return false;
  }
}

class FirestoreCommentRepository implements CommentRepository {
  FirestoreCommentRepository({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;
  final List<AppComment> _comments = [];
  final StreamController<List<AppComment>> _controller =
      StreamController<List<AppComment>>.broadcast();

  FirebaseFirestore? get _db {
    if (!_isFirebaseInitialized()) {
      return null;
    }

    return _firestore ?? FirebaseFirestore.instance;
  }

  @override
  Stream<List<AppComment>> watchForTarget({
    required String targetType,
    required String targetId,
  }) async* {
    final db = _db;
    if (db != null) {
      yield* db
          .collection('comments')
          .where('targetType', isEqualTo: targetType)
          .where('targetId', isEqualTo: targetId)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => AppComment.fromMap(doc.id, doc.data()))
                .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
          )
          .handleError((_) {});
      return;
    }

    yield _filter(targetType: targetType, targetId: targetId);
    yield* _controller.stream.map(
      (_) => _filter(targetType: targetType, targetId: targetId),
    );
  }

  @override
  Future<void> add(AppComment comment) async {
    final db = _db;
    if (db != null && comment.userId != 'local-user') {
      await db.collection('comments').doc(comment.id).set(comment.toMap());

      // Reward +2 coins if comment is meaningful and daily limit is not reached
      final text = comment.text.trim();
      final words =
          text.split(RegExp(r'\s+')).where((w) => w.length > 1).toList();
      final hasNoRepetitivePunctuation =
          !RegExp(r'([!?.@#\$%^&*()_+={}\[\]|\\:;\"<>,~\-\/`])\1{3,}')
              .hasMatch(text);

      if (text.length >= 10 &&
          words.length >= 2 &&
          hasNoRepetitivePunctuation) {
        try {
          final todayStr = DateTime.now().toIso8601String().substring(0, 10);
          final userRef = db.collection('users').doc(comment.userId);

          await db.runTransaction((transaction) async {
            final userDoc = await transaction.get(userRef);
            if (userDoc.exists) {
              final data = userDoc.data() ?? {};
              final lastClaimDate =
                  data['lastCommentCoinsClaimDate'] as String? ?? '';
              int dailyCoinsClaimed =
                  data['dailyCommentCoinsClaimed'] as int? ?? 0;

              if (lastClaimDate != todayStr) {
                dailyCoinsClaimed = 0;
              }

              if (dailyCoinsClaimed < 4) {
                // Max 4 coins (2 comments per day)
                transaction.update(userRef, {
                  'coins': FieldValue.increment(2),
                  'lastCommentCoinsClaimDate': todayStr,
                  'dailyCommentCoinsClaimed':
                      lastClaimDate != todayStr ? 2 : FieldValue.increment(2),
                });
              }
            }
          });
        } catch (_) {}
      }
      return;
    }

    _comments.insert(0, comment);
    _controller.add(_comments);
  }

  @override
  Future<void> delete(String commentId) async {
    final db = _db;
    if (db != null) {
      await db.collection('comments').doc(commentId).delete();
      return;
    }

    _comments.removeWhere((c) => c.id == commentId);
    _controller.add(_comments);
  }

  List<AppComment> _filter({
    required String targetType,
    required String targetId,
  }) {
    return _comments
        .where(
          (comment) =>
              comment.targetType == targetType && comment.targetId == targetId,
        )
        .toList(growable: false);
  }
}
