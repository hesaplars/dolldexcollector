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
