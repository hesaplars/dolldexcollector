import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../main.dart';
import '../core/app_helpers.dart';
import '../core/app_language.dart';
import '../users/user_models.dart';
import '../users/profile_setup_repository.dart';
import '../widgets/doll_widgets.dart';
import '../auth/sign_in_panel.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _roleFilter; // null: Tümü, 'pro': Sadece Pro, 'admin': Yöneticiler
  List<AppUser> _filteredResults = const <AppUser>[];
  bool _isSearching = false;
  bool _isSigningIn = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isSigningIn = true;
    });
    try {
      await performGoogleSignIn(context);
    } finally {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Do not perform initial search so that users list is empty by default
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final myUid = authService.currentUser?.uid ?? '';
    if (myUid.isEmpty) return;

    if (_searchQuery.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _filteredResults = const <AppUser>[];
          _isSearching = false;
        });
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _isSearching = true;
    });

    try {
      // searchUsers handles empty queries by returning first 20 users
      final users = await socialRepository.searchUsers(_searchQuery);
      
      // Filter out current user from search
      var filtered = users.where((u) => u.id != myUid).toList();

      // Apply local role filter if set
      if (_roleFilter == 'pro') {
        filtered = filtered.where((u) => u.isPro && u.role != 'admin').toList();
      } else if (_roleFilter == 'admin') {
        filtered = filtered.where((u) => u.role == 'admin').toList();
      }

      if (!mounted) return;
      setState(() {
        _filteredResults = filtered;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Arama sırasında hata oluştu: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _sendFriendRequest(BuildContext context, String targetUserId) async {
    final myUid = authService.currentUser?.uid ?? '';
    if (myUid.isEmpty) return;
    await socialRepository.sendFriendRequest(
      fromUserId: myUid,
      toUserId: targetUserId,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t(context, 'friendRequestSent'))),
    );
  }

  void _showUserFilterSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: isDark ? const Color(0xFF0E0818) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: const Color(0xFFEC008C).withOpacity(0.25), width: 1.0),
      ),
      builder: (context) {
        final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
        final currentUser = authService.currentUser;

        return StreamBuilder<ProfileSetupStatus>(
          stream: currentUser != null
              ? profileSetupRepository.watch(currentUser.uid)
              : const Stream.empty(),
          builder: (context, snap) {
            final isPro = snap.data?.isPro == true;

            return GothicIvyContainer(
              borderRadius: 20,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr ? 'Kullanıcı Filtresi' : 'User Filter',
                    style: TextStyle(
                      fontFamily: 'Cinzel',
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildFilterOption(context, null, tr ? 'Tüm Kullanıcılar' : 'All Users', isPro),
                  const SizedBox(height: 8),
                  _buildFilterOption(context, 'pro', tr ? 'Sadece Pro Üyeler' : 'Pro Members Only', isPro),
                  const SizedBox(height: 8),
                  _buildFilterOption(context, 'admin', tr ? 'Yöneticiler' : 'Staff / Admins', isPro),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterOption(BuildContext context, String? type, String label, bool isPro) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _roleFilter == type;
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;

    return InkWell(
      onTap: () {
        if (type != null && !isPro) {
          Navigator.of(context).pop();
          showGothicConfirmDialog(
            context,
            title: tr ? 'Pro Arama Filtresi' : 'Pro Search Filter',
            content: tr
                ? 'Pro ve Yönetici filtrelerini kullanabilmek için DollDex Pro üyesi olmalısınız.'
                : 'You must be a DollDex Pro member to use Pro and Staff filters.',
            confirmText: tr ? 'Pro\'ya Geç' : 'Upgrade to Pro',
            cancelText: tr ? 'Vazgeç' : 'Cancel',
          ).then((confirmed) {
            if (confirmed && context.mounted) {
              showProSubscriptionModal(context);
            }
          });
        } else {
          setState(() {
            _roleFilter = type;
          });
          Navigator.of(context).pop();
          _performSearch();
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFEC008C).withOpacity(isDark ? 0.15 : 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFEC008C).withOpacity(0.5)
                : const Color(0xFF2C1F45).withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? (isDark ? Colors.white : const Color(0xFFEC008C))
                      : (isDark ? Colors.white60 : Colors.black87),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (type != null && !isPro)
              Icon(
                Icons.lock_rounded,
                size: 14,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNeonIcon(BuildContext context, IconData icon, {double size = 24}) {
    return SafeShaderMask(
      shaderCallback: (bounds) {
        return const LinearGradient(
          colors: [Color(0xFFEC008C), Color(0xFF00FFCC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds);
      },
      child: Icon(
        icon,
        size: size,
        color: Colors.white,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PageShell(
      listViewKey: const PageStorageKey('user_search_scroll'),
      title: tr ? 'Kullanıcı Ara' : 'Search Users',
      subtitle: tr ? 'Topluluktaki diğer koleksiyoncuları bulun ve takip edin.' : 'Find and follow other collectors in the community.',
      child: Column(
        children: [
          GothicIvyContainer(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            borderRadius: 16,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                      _performSearch();
                    },
                    style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87, fontFamily: 'Outfit'),
                    decoration: InputDecoration(
                      hintText: tr ? 'Kullanıcı adı veya isim yaz...' : 'Type username or display name...',
                      hintStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 14, fontFamily: 'Outfit'),
                      prefixIcon: _buildNeonIcon(context, Icons.search_rounded, size: 20),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_searchQuery.trim().isEmpty)
            const SizedBox.shrink()
          else if (_filteredResults.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  tr ? 'Kullanıcı bulunamadı.' : 'No users found.',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    color: isDark ? Colors.white30 : Colors.black38,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredResults.length,
              itemBuilder: (context, index) {
                final target = _filteredResults[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFEC008C).withOpacity(isDark ? 0.3 : 0.15),
                      width: 1.2,
                    ),
                    color: isDark ? const Color(0xFF130820) : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEC008C).withOpacity(0.04),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ListTile(
                    onTap: () {
                      if (target.username.isNotEmpty) {
                        context.go('/u/${target.username}?from=/user_search');
                      } else {
                        context.go('/users/${target.id}?from=/user_search');
                      }
                    },
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: buildAvatarHelper(target.avatarId, target.avatarFrameColor, size: 40),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (target.selectedBadge.isNotEmpty) ...[
                          ProfileBadgeWidget(badgeId: target.selectedBadge, size: 8),
                          const SizedBox(height: 2),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                target.username.isEmpty ? target.displayName : '@${target.username}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                            if (target.isPro) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFEC008C), Color(0xFF8338EC)],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  target.isAdmin ? (tr ? 'EDİTÖR' : 'STAFF') : 'PRO',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        target.bio.isNotEmpty ? target.bio : (tr ? 'Koleksiyoncu' : 'Collector'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Outfit',
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: tr ? 'Arkadaş İsteği Gönder' : 'Send Friend Request',
                          icon: const Icon(Icons.person_add_alt_1_rounded, size: 20, color: Color(0xFF00FFCC)),
                          onPressed: () => _sendFriendRequest(context, target.id),
                        ),
                        IconButton(
                          tooltip: tr ? 'Profili Görüntüle' : 'View Profile',
                          icon: const Icon(Icons.account_circle_outlined, size: 20, color: Color(0xFFEC008C)),
                          onPressed: () {
                            if (target.username.isNotEmpty) {
                              context.go('/u/${target.username}?from=/user_search');
                            } else {
                              context.go('/users/${target.id}?from=/user_search');
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
