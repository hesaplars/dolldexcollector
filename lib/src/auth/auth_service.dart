import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

bool _isFirebaseInitialized() {
  try {
    return Firebase.apps.isNotEmpty;
  } catch (_) {
    return false;
  }
}

class AuthService {
  AuthService({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  })  : _firebaseAuth = firebaseAuth,
        _googleSignIn = googleSignIn ??
            (kIsWeb
                ? GoogleSignIn(
                    clientId:
                        '98984107875-jntfl74i0tco8i8u78durs6mv2654n3v.apps.googleusercontent.com',
                  )
                : GoogleSignIn());

  final FirebaseAuth? _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  FirebaseAuth? get _auth {
    if (!_isFirebaseInitialized()) {
      return null;
    }
    return _firebaseAuth ?? FirebaseAuth.instance;
  }

  Stream<User?> get authStateChanges async* {
    if (_firebaseAuth != null) {
      yield* _firebaseAuth!.authStateChanges();
      return;
    }
    for (int i = 0; i < 50; i++) {
      if (_isFirebaseInitialized()) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (_isFirebaseInitialized()) {
      yield* FirebaseAuth.instance.authStateChanges();
    } else {
      yield null;
    }
  }

  User? get currentUser => _auth?.currentUser;

  Future<UserCredential> signInWithGoogle() async {
    final auth = _auth;
    if (auth == null) {
      throw StateError('Firebase bağlantısı henüz hazır değil.');
    }

    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw const AuthCancelledException();
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await auth.signInWithCredential(credential);
    await _syncUserProfile(userCredential.user);
    return userCredential;
  }

  Future<void> signOut() async {
    await Future.wait([
      _googleSignIn.signOut(),
      _auth?.signOut() ?? Future<void>.value(),
    ]);
  }
}

Future<void> _syncUserProfile(User? user) async {
  if (user == null || !_isFirebaseInitialized()) {
    return;
  }

  final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
  final snapshot = await userRef.get();

  await userRef.set({
    'displayName': user.displayName,
    'email': user.email,
    'photoUrl': user.photoURL,
    if (!snapshot.exists) 'role': 'user',
    'lastSeen': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

class AuthCancelledException implements Exception {
  const AuthCancelledException();
}
