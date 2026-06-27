import 'dart:async';
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
    this.coins = 10,
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
    this.dailyRewardedAdCount = 0,
    this.lastRewardedAdDate = '',
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
  final int dailyRewardedAdCount;
  final String lastRewardedAdDate;

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
    final finalAvatarId = (rawAvatarId.isEmpty && photoUrlVal.isNotEmpty)
        ? photoUrlVal
        : rawAvatarId;

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
      featuredEntryIds:
          List<String>.from(map['featuredEntryIds'] as List? ?? []),
      coins: map['coins'] as int? ?? 10,
      unlockedBadges:
          List<String>.from(map['unlockedBadges'] as List? ?? ['novice']),
      selectedBadge: map['selectedBadge'] as String? ?? '',
      unlockedAvatars: List<String>.from(map['unlockedAvatars'] as List? ?? []),
      unlockedFrames: List<String>.from(map['unlockedFrames'] as List? ?? []),
      unlockedCovers: List<String>.from(map['unlockedCovers'] as List? ?? []),
      lastDailyClaim: parsedDailyClaim,
      lastCommentCoinsClaimDate:
          map['lastCommentCoinsClaimDate'] as String? ?? '',
      dailyCommentCoinsClaimed: map['dailyCommentCoinsClaimed'] as int? ?? 0,
      isBanned: map['isBanned'] as bool? ?? false,
      banUntil: parsedBanUntil,
      selectedTheme: map['selectedTheme'] as String? ?? 'goth_dark',
      dailyRewardedAdCount: map['dailyRewardedAdCount'] as int? ?? 0,
      lastRewardedAdDate: map['lastRewardedAdDate'] as String? ?? '',
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

  static const minAge = 14;
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

    final source =
        db.collection('users').doc(userId).snapshots().map((snapshot) {
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

      if (previousUsername.isNotEmpty &&
          previousUsername != normalizedUsername) {
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

  Future<void> _processRequest({
    required String collectionName,
    required Map<String, dynamic> data,
  }) async {
    final db = _db;
    if (db == null) return;

    final docRef = await db.collection(collectionName).add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final completer = Completer<void>();
    StreamSubscription<DocumentSnapshot>? subscription;

    subscription = docRef.snapshots().listen((snapshot) {
      if (!snapshot.exists) return;
      final statusData = snapshot.data() as Map<String, dynamic>? ?? {};
      final status = statusData['status'] as String? ?? 'pending';
      if (status == 'success') {
        subscription?.cancel();
        completer.complete();
      } else if (status == 'error') {
        subscription?.cancel();
        final errorReason = statusData['errorReason'] as String? ?? 'Request failed';
        completer.completeError(Exception(errorReason));
      }
    }, onError: (err) {
      subscription?.cancel();
      completer.completeError(err);
    });

    await completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        subscription?.cancel();
        throw TimeoutException('Request timed out. Please try again.');
      },
    );
  }

  Future<void> unlockBadge(String userId, String badgeId, int coinCost) async {
    await _processRequest(
      collectionName: 'unlockRequests',
      data: {
        'userId': userId,
        'itemType': 'badge',
        'itemId': badgeId,
        'status': 'pending',
      },
    );
  }

  Future<void> unlockAvatar(
      String userId, String avatarId, int coinCost) async {
    await _processRequest(
      collectionName: 'unlockRequests',
      data: {
        'userId': userId,
        'itemType': 'avatar',
        'itemId': avatarId,
        'status': 'pending',
      },
    );
  }

  Future<void> unlockFrame(
      String userId, String frameColor, int coinCost) async {
    await _processRequest(
      collectionName: 'unlockRequests',
      data: {
        'userId': userId,
        'itemType': 'frame',
        'itemId': frameColor,
        'status': 'pending',
      },
    );
  }

  Future<void> unlockCover(String userId, String coverId, int coinCost) async {
    await _processRequest(
      collectionName: 'unlockRequests',
      data: {
        'userId': userId,
        'itemType': 'cover',
        'itemId': coverId,
        'status': 'pending',
      },
    );
  }

  Future<void> claimDailyCoins(String userId) async {
    final db = _db;
    if (db == null) return;
    // Fire-and-forget: belgeyi yaz, Cloud Function'ı bekleme.
    // Jeton profil stream'den otomatik güncellenir.
    await db.collection('dailyClaimRequests').add({
      'userId': userId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Rewarded reklam izlendikten sonra +5 jeton talep eder.
  /// Günde maksimum 5 kez çağrılabilir (kontrol AppScaffold'da yapılır).
  Future<void> claimRewardedAdCoins(String userId) async {
    final db = _db;
    if (db == null) return;
    await db.collection('rewardedAdRequests').add({
      'userId': userId,
      'status': 'pending',
      'coinsAmount': 5,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> buyCoinPackage(String userId, int coinsAmount) async {
    await _processRequest(
      collectionName: 'coinPurchaseRequests',
      data: {
        'userId': userId,
        'coinsAmount': coinsAmount,
        'status': 'pending',
      },
    );
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

  Future<void> updateBanStatus(String userId,
      {required bool isBanned, DateTime? banUntil}) async {
    final db = _db;
    if (db == null) return;
    await db.collection('users').doc(userId).set({
      'isBanned': isBanned,
      'banUntil': banUntil != null ? Timestamp.fromDate(banUntil) : null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateRoleAndPro(String userId,
      {required String role, required bool isPro}) async {
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
