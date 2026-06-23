class AppUser {
  const AppUser({
    required this.id,
    required this.displayName,
    required this.email,
    required this.photoUrl,
    required this.role,
    required this.isPro,
    this.bio = '',
    this.username = '',
    this.avatarId = '',
    this.avatarFrameColor = '',
    this.featuredEntryIds = const [],
    this.selectedBadge = '',
  });

  final String id;
  final String displayName;
  final String email;
  final String photoUrl;
  final String role;
  final bool isPro;
  final String bio;
  final String username;
  final String avatarId;
  final String avatarFrameColor;
  final List<String> featuredEntryIds;
  final String selectedBadge;

  bool get isAdmin => role == 'admin';

  Map<String, Object?> toMap() {
    return {
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'role': role,
      'isPro': isPro,
      'bio': bio,
      'username': username,
      'usernameLower': username.toLowerCase(),
      'avatarId': avatarId,
      'avatarFrameColor': avatarFrameColor,
      'featuredEntryIds': featuredEntryIds,
      'selectedBadge': selectedBadge,
    };
  }

  factory AppUser.fromMap(String id, Map<String, Object?> map) {
    final roleVal = map['role'] as String? ?? 'user';
    final rawAvatarId = map['avatarId'] as String? ?? '';
    final photoUrlVal = map['photoUrl'] as String? ?? '';
    final finalAvatarId = (rawAvatarId.isEmpty && photoUrlVal.isNotEmpty)
        ? photoUrlVal
        : rawAvatarId;

    return AppUser(
      id: id,
      displayName: map['displayName'] as String? ?? 'Collector',
      email: map['email'] as String? ?? '',
      photoUrl: photoUrlVal,
      role: roleVal,
      isPro: (map['isPro'] as bool? ?? false) || roleVal == 'admin',
      bio: map['bio'] as String? ?? '',
      username: map['username'] as String? ?? '',
      avatarId: finalAvatarId,
      avatarFrameColor: map['avatarFrameColor'] as String? ?? '',
      featuredEntryIds:
          List<String>.from(map['featuredEntryIds'] as List? ?? []),
      selectedBadge: map['selectedBadge'] as String? ?? '',
    );
  }
}
