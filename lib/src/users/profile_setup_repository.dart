import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class ProfileSetupStatus {
  const ProfileSetupStatus({
    required this.userId,
    required this.displayName,
    required this.username,
    required this.birthYear,
    required this.privacyVersion,
    required this.termsVersion,
    required this.role,
    required this.isPro,
    required this.avatarId,
    required this.avatarFrameColor,
    required this.coverId,
  });

  final String userId;
  final String displayName;
  final String username;
  final int? birthYear;
  final String privacyVersion;
  final String termsVersion;
  final String role;
  final bool isPro;
  final String avatarId;
  final String avatarFrameColor;
  final String coverId;

  bool get isComplete {
    return username.isNotEmpty &&
        birthYear != null &&
        privacyVersion == ProfileSetupRepository.privacyVersion &&
        termsVersion == ProfileSetupRepository.termsVersion;
  }

  factory ProfileSetupStatus.fromMap(String userId, Map<String, Object?> map) {
    final roleVal = map['role'] as String? ?? 'user';
    final isProVal = map['isPro'] as bool? ?? false;
    return ProfileSetupStatus(
      userId: userId,
      displayName: map['displayName'] as String? ?? 'Collector',
      username: map['username'] as String? ?? '',
      birthYear: map['birthYear'] as int?,
      privacyVersion: map['acceptedPrivacyVersion'] as String? ?? '',
      termsVersion: map['acceptedTermsVersion'] as String? ?? '',
      role: roleVal,
      isPro: isProVal || roleVal == 'admin',
      avatarId: map['avatarId'] as String? ?? '',
      avatarFrameColor: map['avatarFrameColor'] as String? ?? '',
      coverId: map['coverId'] as String? ?? 'default',
    );
  }
}

class UsernameTakenException implements Exception {
  const UsernameTakenException();
}

class UsernameChangeLockedException implements Exception {
  const UsernameChangeLockedException();
}

bool _isFirebaseInitialized() {
  try {
    return Firebase.apps.isNotEmpty;
  } catch (_) {
    return false;
  }
}

class ProfileSetupRepository {
  ProfileSetupRepository({FirebaseFirestore? firestore})
      : _firestore = firestore;

  static const minAge = 13;
  static const usernameChangeCooldownDays = 183;
  static const privacyVersion = '2026-06-13';
  static const termsVersion = '2026-06-13';

  final FirebaseFirestore? _firestore;

  FirebaseFirestore? get _db {
    if (!_isFirebaseInitialized()) {
      return null;
    }

    return _firestore ?? FirebaseFirestore.instance;
  }

  Stream<ProfileSetupStatus> watch(String userId) {
    final db = _db;
    if (db == null) {
      return Stream.value(
        ProfileSetupStatus(
          userId: userId,
          displayName: 'Collector',
          username: '',
          birthYear: null,
          privacyVersion: '',
          termsVersion: '',
          role: 'user',
          isPro: false,
          avatarId: '',
          avatarFrameColor: '',
          coverId: 'default',
        ),
      );
    }

    return db.collection('users').doc(userId).snapshots().map((snapshot) {
      return ProfileSetupStatus.fromMap(userId, snapshot.data() ?? {});
    });
  }

  Future<void> saveAvatar({
    required String userId,
    required String avatarId,
    required String avatarFrameColor,
  }) async {
    final db = _db;
    if (db == null) {
      return;
    }

    await db.collection('users').doc(userId).set({
      'avatarId': avatarId,
      'avatarFrameColor': avatarFrameColor,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveCover({
    required String userId,
    required String coverId,
  }) async {
    final db = _db;
    if (db == null) {
      return;
    }

    await db.collection('users').doc(userId).set({
      'coverId': coverId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveRequiredProfile({
    required String userId,
    required String username,
    required int birthYear,
  }) async {
    final db = _db;
    if (db == null) {
      return;
    }

    final normalizedUsername = normalizeUsername(username);
    if (!isValidUsername(normalizedUsername)) {
      throw const FormatException('Invalid username');
    }

    final userRef = db.collection('users').doc(userId);
    final usernameRef = db.collection('usernames').doc(normalizedUsername);

    await db.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      final usernameSnapshot = await transaction.get(usernameRef);
      final existingOwner = usernameSnapshot.data()?['userId'] as String?;

      if (usernameSnapshot.exists && existingOwner != userId) {
        throw const UsernameTakenException();
      }

      final previousUsername =
          userSnapshot.data()?['usernameLower'] as String? ?? '';
      final usernameChanged =
          previousUsername.isNotEmpty && previousUsername != normalizedUsername;
      final lastChangedAt = _dateFromMapValue(
        userSnapshot.data()?['usernameChangedAt'],
      );
      if (usernameChanged &&
          lastChangedAt != null &&
          DateTime.now().difference(lastChangedAt).inDays <
              usernameChangeCooldownDays) {
        throw const UsernameChangeLockedException();
      }

      if (previousUsername.isNotEmpty && previousUsername != normalizedUsername) {
        transaction.delete(db.collection('usernames').doc(previousUsername));
      }

      transaction.set(
        usernameRef,
        {
          'userId': userId,
          'username': normalizedUsername,
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      transaction.set(
        userRef,
        {
          'username': normalizedUsername,
          'usernameLower': normalizedUsername,
          'birthYear': birthYear,
          'minimumAgeConfirmed': true,
          'acceptedPrivacyVersion': privacyVersion,
          'acceptedTermsVersion': termsVersion,
          'profileCompletedAt': FieldValue.serverTimestamp(),
          if (previousUsername.isEmpty || usernameChanged)
            'usernameChangedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  static String normalizeUsername(String value) {
    return value.trim().toLowerCase();
  }

  static bool isValidUsername(String value) {
    return RegExp(r'^[a-z0-9_]{3,15}$').hasMatch(value);
  }

  static int ageFromBirthYear(int birthYear) {
    return DateTime.now().year - birthYear;
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
