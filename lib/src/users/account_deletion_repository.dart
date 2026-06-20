import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

bool _isFirebaseInitialized() {
  try {
    return Firebase.apps.isNotEmpty;
  } catch (_) {
    return false;
  }
}

class AccountDeletionRepository {
  AccountDeletionRepository({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore? get _db {
    if (!_isFirebaseInitialized()) {
      return null;
    }

    return _firestore ?? FirebaseFirestore.instance;
  }

  Future<void> requestDeletion({
    required String userId,
    required String email,
    required String reason,
  }) async {
    final db = _db;
    if (db == null) {
      return;
    }

    await db.collection('accountDeletionRequests').doc(userId).set({
      'userId': userId,
      'email': email,
      'reason': reason,
      'status': 'open',
      'requestedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
