import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../core/replay_stream.dart';

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
    this.photoUrl = '',
    this.featuredEntryIds = const [],
    this.coins = 20,
    this.unlockedBadges = const ['novice'],
    this.selectedBadge = '',
    this.unlockedAvatars = const [],
    this.unlockedFrames = const [],
    this.unlockedCovers = const [],
    this.lastDailyClaim,
    this.lastCommentCoinsClaimDate = '',
    this.dailyCommentCoinsClaimed = 0,
    this.isBanned = false,
    this.banUntil,
    this.selectedTheme = 'goth_dark',
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
  final String photoUrl;
  final List<String> featuredEntryIds;
  final int coins;
  final List<String> unlockedBadges;
  final String selectedBadge;
  final List<String> unlockedAvatars;
  final List<String> unlockedFrames;
  final List<String> unlockedCovers;
  final DateTime? lastDailyClaim;
  final String lastCommentCoinsClaimDate;
  final int dailyCommentCoinsClaimed;
  final bool isBanned;
  final DateTime? banUntil;
  final String selectedTheme;

  bool get isComplete {
    return username.isNotEmpty &&
        birthYear != null &&
        privacyVersion == ProfileSetupRepository.privacyVersion &&
        termsVersion == ProfileSetupRepository.termsVersion;
  }

  factory ProfileSetupStatus.fromMap(String userId, Map<String, Object?> map) {
    final roleVal = map['role'] as String? ?? 'user';
    final isProVal = map['isPro'] as bool? ?? false;
    
    DateTime? parsedDailyClaim;
    final rawClaim = map['lastDailyClaim'];
    if (rawClaim is Timestamp) {
      parsedDailyClaim = rawClaim.toDate();
    } else if (rawClaim is String) {
      parsedDailyClaim = DateTime.tryParse(rawClaim);
    }

    DateTime? parsedBanUntil;
    final rawBanUntil = map['banUntil'];
    if (rawBanUntil is Timestamp) {
      parsedBanUntil = rawBanUntil.toDate();
    } else if (rawBanUntil is String) {
      parsedBanUntil = DateTime.tryParse(rawBanUntil);
    }

    final rawAvatarId = map['avatarId'] as String? ?? '';
    final photoUrlVal = map['photoUrl'] as String? ?? '';
    final finalAvatarId = (rawAvatarId.isEmpty && photoUrlVal.isNotEmpty) ? photoUrlVal : rawAvatarId;

    return ProfileSetupStatus(
      userId: userId,
      displayName: map['displayName'] as String? ?? 'Collector',
      username: map['username'] as String? ?? '',
      birthYear: map['birthYear'] as int?,
      privacyVersion: map['acceptedPrivacyVersion'] as String? ?? '',
      termsVersion: map['acceptedTermsVersion'] as String? ?? '',
      role: roleVal,
      isPro: isProVal || roleVal == 'admin',
      avatarId: finalAvatarId,
      avatarFrameColor: map['avatarFrameColor'] as String? ?? '',
      coverId: map['coverId'] as String? ?? 'default',
      photoUrl: photoUrlVal,
      featuredEntryIds: List<String>.from(map['featuredEntryIds'] as List? ?? []),
      coins: map['coins'] as int? ?? 20,
      unlockedBadges: List<String>.from(map['unlockedBadges'] as List? ?? ['novice']),
      selectedBadge: map['selectedBadge'] as String? ?? '',
      unlockedAvatars: List<String>.from(map['unlockedAvatars'] as List? ?? []),
      unlockedFrames: List<String>.from(map['unlockedFrames'] as List? ?? []),
      unlockedCovers: List<String>.from(map['unlockedCovers'] as List? ?? []),
      lastDailyClaim: parsedDailyClaim,
      lastCommentCoinsClaimDate: map['lastCommentCoinsClaimDate'] as String? ?? '',
      dailyCommentCoinsClaimed: map['dailyCommentCoinsClaimed'] as int? ?? 0,
      isBanned: map['isBanned'] as bool? ?? false,
      banUntil: parsedBanUntil,
      selectedTheme: map['selectedTheme'] as String? ?? 'goth_dark',
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
  final Map<String, ReplayStream<ProfileSetupStatus>> _watchCache = {};

  FirebaseFirestore? get _db {
    if (!_isFirebaseInitialized()) {
      return null;
    }

    return _firestore ?? FirebaseFirestore.instance;
  }

  Stream<ProfileSetupStatus> watch(String userId) {
    if (_watchCache.containsKey(userId)) {
      return _watchCache[userId]!;
    }

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

    final source = db.collection('users').doc(userId).snapshots().map((snapshot) {
      return ProfileSetupStatus.fromMap(userId, snapshot.data() ?? {});
    });

    final stream = ReplayStream<ProfileSetupStatus>(source);
    _watchCache[userId] = stream;
    return stream;
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

  Future<void> saveSelectedTheme(String userId, String themeKey) async {
    final db = _db;
    if (db == null) {
      return;
    }

    await db.collection('users').doc(userId).set({
      'selectedTheme': themeKey,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateFeaturedEntries({
    required String userId,
    required List<String> entryIds,
  }) async {
    final db = _db;
    if (db == null) {
      return;
    }

    await db.collection('users').doc(userId).set({
      'featuredEntryIds': entryIds,
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

  Future<void> saveSelectedBadge(String userId, String badgeId) async {
    final db = _db;
    if (db == null) return;
    await db.collection('users').doc(userId).set({
      'selectedBadge': badgeId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> unlockBadge(String userId, String badgeId, int coinCost) async {
    final db = _db;
    if (db == null) return;
    final docRef = db.collection('users').doc(userId);
    await db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final data = snapshot.data() ?? {};
      final currentCoins = data['coins'] as int? ?? 20;
      transaction.set(docRef, {
        'unlockedBadges': FieldValue.arrayUnion([badgeId]),
        if (coinCost > 0) 'coins': currentCoins - coinCost,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> unlockAvatar(String userId, String avatarId, int coinCost) async {
    final db = _db;
    if (db == null) return;
    final docRef = db.collection('users').doc(userId);
    await db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final data = snapshot.data() ?? {};
      final currentCoins = data['coins'] as int? ?? 20;
      transaction.set(docRef, {
        'unlockedAvatars': FieldValue.arrayUnion([avatarId]),
        if (coinCost > 0) 'coins': currentCoins - coinCost,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> unlockFrame(String userId, String frameColor, int coinCost) async {
    final db = _db;
    if (db == null) return;
    final docRef = db.collection('users').doc(userId);
    await db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final data = snapshot.data() ?? {};
      final currentCoins = data['coins'] as int? ?? 20;
      transaction.set(docRef, {
        'unlockedFrames': FieldValue.arrayUnion([frameColor]),
        if (coinCost > 0) 'coins': currentCoins - coinCost,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> unlockFrameDirect(String userId, String frameColor) async {
    final db = _db;
    if (db == null) return;
    await db.collection('users').doc(userId).set({
      'unlockedFrames': FieldValue.arrayUnion([frameColor]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> unlockCover(String userId, String coverId, int coinCost) async {
    final db = _db;
    if (db == null) return;
    final docRef = db.collection('users').doc(userId);
    await db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final data = snapshot.data() ?? {};
      final currentCoins = data['coins'] as int? ?? 20;
      transaction.set(docRef, {
        'unlockedCovers': FieldValue.arrayUnion([coverId]),
        if (coinCost > 0) 'coins': currentCoins - coinCost,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> claimDailyCoins(String userId) async {
    final db = _db;
    if (db == null) return;
    final docRef = db.collection('users').doc(userId);
    await db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final data = snapshot.data() ?? {};
      final currentCoins = data['coins'] as int? ?? 20;
      transaction.set(docRef, {
        'coins': currentCoins + 5,
        'lastDailyClaim': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> buyCoinPackage(String userId, int coinsAmount) async {
    final db = _db;
    if (db == null) return;
    final docRef = db.collection('users').doc(userId);
    await db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final data = snapshot.data() ?? {};
      final currentCoins = data['coins'] as int? ?? 20;
      transaction.set(docRef, {
        'coins': currentCoins + coinsAmount,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<ProfileSetupStatus?> getProfile(String userId) async {
    final db = _db;
    if (db == null) return null;
    final doc = await db.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    return ProfileSetupStatus.fromMap(userId, doc.data() ?? {});
  }

  Future<void> updateCoins(String userId, int newCoins) async {
    final db = _db;
    if (db == null) return;
    await db.collection('users').doc(userId).set({
      'coins': newCoins,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateBanStatus(String userId, {required bool isBanned, DateTime? banUntil}) async {
    final db = _db;
    if (db == null) return;
    await db.collection('users').doc(userId).set({
      'isBanned': isBanned,
      'banUntil': banUntil != null ? Timestamp.fromDate(banUntil) : null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateRoleAndPro(String userId, {required String role, required bool isPro}) async {
    final db = _db;
    if (db == null) return;
    await db.collection('users').doc(userId).set({
      'role': role,
      'isPro': isPro,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> resetProfileContent(String userId) async {
    final db = _db;
    if (db == null) return;
    await db.collection('users').doc(userId).set({
      'displayName': 'Collector',
      'avatarId': '',
      'coverId': 'default',
      'featuredEntryIds': <String>[],
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> adminDeleteUserAccount(String userId, String username) async {
    final db = _db;
    if (db == null) return;
    final normalizedUsername = normalizeUsername(username);

    // Fetch collectionEntries owned by this user
    final entriesSnapshot = await db
        .collection('collectionEntries')
        .where('userId', isEqualTo: userId)
        .get();

    // Fetch notifications owned by this user
    final notificationsSnapshot = await db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .get();

    final batch = db.batch();

    // Delete user profile document
    batch.delete(db.collection('users').doc(userId));

    // Delete username mapping document (if any)
    if (normalizedUsername.isNotEmpty) {
      batch.delete(db.collection('usernames').doc(normalizedUsername));
    }

    // Delete collection entries
    for (final doc in entriesSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Delete notifications
    for (final doc in notificationsSnapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
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
