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
    };
  }

  factory AppUser.fromMap(String id, Map<String, Object?> map) {
    final roleVal = map['role'] as String? ?? 'user';
    return AppUser(
      id: id,
      displayName: map['displayName'] as String? ?? 'Collector',
      email: map['email'] as String? ?? '',
      photoUrl: map['photoUrl'] as String? ?? '',
      role: roleVal,
      isPro: (map['isPro'] as bool? ?? false) || roleVal == 'admin',
      bio: map['bio'] as String? ?? '',
      username: map['username'] as String? ?? '',
      avatarId: map['avatarId'] as String? ?? '',
      avatarFrameColor: map['avatarFrameColor'] as String? ?? '',
      featuredEntryIds: List<String>.from(map['featuredEntryIds'] as List? ?? []),
    );
  }
}
