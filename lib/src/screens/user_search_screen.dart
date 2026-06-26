import 'dart:async';
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
  StreamSubscription<List<String>>? _friendsSubscription;
  Set<String> _friendIds = const {};

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
    _subscribeToFriends();
  }

  void _subscribeToFriends() {
    final myUid = authService.currentUser?.uid ?? '';
    if (myUid.isNotEmpty) {
      _friendsSubscription =
          socialRepository.watchFriends(myUid).listen((uids) {
        if (mounted) {
          setState(() {
            _friendIds = uids.toSet();
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _friendsSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final myUid = authService.currentUser?.uid ?? '';
    if (myUid.isEmpty) return;

    if (_searchQuery.trim().isEmpty) {
      if (_roleFilter == 'admin') {
        if (!mounted) return;
        setState(() {
          _isSearching = true;
        });
        try {
          final admins = await socialRepository.fetchAdmins();
          var filtered = admins.where((u) => u.id != myUid).toList();
          if (!mounted) return;
          setState(() {
            _filteredResults = filtered;
          });
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Yöneticiler yüklenirken hata oluştu: $e')),
          );
        } finally {
          if (mounted) {
            setState(() {
              _isSearching = false;
            });
          }
        }
        return;
      }

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

  Future<void> _sendFriendRequest(
      BuildContext context, String targetUserId) async {
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Theme.of(context).dividerColor, width: 1.0),
      ),
      builder: (context) {
        final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr ? 'Kullanıcı Filtresi' : 'User Filter',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              _buildFilterOption(
                  context, null, tr ? 'Tüm Kullanıcılar' : 'All Users'),
              const SizedBox(height: 8),
              _buildFilterOption(context, 'pro',
                  tr ? 'Sadece Pro Üyeler' : 'Pro Members Only'),
              const SizedBox(height: 8),
              _buildFilterOption(
                  context, 'admin', tr ? 'Yöneticiler' : 'Staff / Admins'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterOption(BuildContext context, String? type, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _roleFilter == type;

    return InkWell(
      onTap: () {
        setState(() {
          _roleFilter = type;
        });
        Navigator.of(context).pop();
        _performSearch();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context)
                  .colorScheme
                  .primary
                  .withOpacity(isDark ? 0.15 : 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
                : Theme.of(context).dividerColor,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNeonIcon(BuildContext context, IconData icon,
      {double size = 24}) {
    return SafeShaderMask(
      shaderCallback: (bounds) {
        return LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
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
      subtitle: tr
          ? 'Topluluktaki diğer koleksiyoncuları bulun ve takip edin.'
          : 'Find and follow other collectors in the community.',
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? DollDexTheme.darkPanel : DollDexTheme.panel,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: isDark ? DollDexTheme.darkLine : DollDexTheme.line),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.22 : 0.09),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 4),
                _buildNeonIcon(context, Icons.search_rounded, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                      _performSearch();
                    },
                    style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white : DollDexTheme.ink,
                        fontFamily: 'Outfit'),
                    decoration: InputDecoration(
                      hintText: tr
                          ? 'Kullanıcı adı veya isim yaz...'
                          : 'Type username or display name...',
                      hintStyle: TextStyle(
                          color: isDark ? Colors.white60 : DollDexTheme.cocoa,
                          fontSize: 13,
                          fontFamily: 'Outfit'),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => _showUserFilterSheet(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            isDark ? DollDexTheme.darkLine : DollDexTheme.line,
                        width: 1.0,
                      ),
                      color:
                          isDark ? DollDexTheme.darkPaper : DollDexTheme.mist,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildNeonIcon(context, Icons.tune_rounded, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          _roleFilter == null
                              ? (tr ? 'Hepsi' : 'All')
                              : (_roleFilter == 'pro'
                                  ? 'Pro'
                                  : (tr ? 'Yönetici' : 'Staff')),
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : DollDexTheme.ink,
                          ),
                        ),
                      ],
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
          else if (_filteredResults.isNotEmpty)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredResults.length,
              itemBuilder: (context, index) {
                final target = _filteredResults[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).dividerColor,
                      width: 1.2,
                    ),
                    color: Theme.of(context).colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.04),
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
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: buildAvatarHelper(
                        context, target.avatarId, target.avatarFrameColor,
                        size: 44),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (target.selectedBadge.isNotEmpty) ...[
                          ProfileBadgeWidget(
                              badgeId: target.selectedBadge, size: 8),
                          const SizedBox(height: 2),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                target.username.isEmpty
                                    ? target.displayName
                                    : '@${target.username}',
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
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Theme.of(context).colorScheme.primary,
                                      Theme.of(context).colorScheme.secondary,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  target.isAdmin
                                      ? (tr ? 'EDİTÖR' : 'STAFF')
                                      : 'PRO',
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
                        target.bio.isNotEmpty
                            ? target.bio
                            : (tr ? 'Koleksiyoncu' : 'Collector'),
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
                        if (!_friendIds.contains(target.id))
                          IconButton(
                            tooltip: tr
                                ? 'Arkadaş İsteği Gönder'
                                : 'Send Friend Request',
                            icon: Icon(Icons.person_add_alt_1_rounded,
                                size: 20,
                                color: Theme.of(context).colorScheme.secondary),
                            onPressed: () =>
                                _sendFriendRequest(context, target.id),
                          ),
                        IconButton(
                          tooltip: tr ? 'Profili Görüntüle' : 'View Profile',
                          icon: Icon(Icons.account_circle_outlined,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary),
                          onPressed: () {
                            if (target.username.isNotEmpty) {
                              context.go(
                                  '/u/${target.username}?from=/user_search');
                            } else {
                              context
                                  .go('/users/${target.id}?from=/user_search');
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            )
          else if (_searchQuery.trim().isEmpty)
            const SizedBox.shrink()
          else
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
            ),
        ],
      ),
    );
  }
}
