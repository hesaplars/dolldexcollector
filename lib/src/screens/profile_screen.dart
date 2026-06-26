import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../main.dart';
import '../auth/sign_in_panel.dart';
import '../auth/auth_service.dart';
import '../catalog/catalog_models.dart';
import '../comments/comment_models.dart';
import '../core/app_helpers.dart';
import '../core/app_language.dart';
import '../moderation/report_models.dart';
import '../social/social_models.dart';
import '../users/profile_setup_repository.dart';
import '../users/user_models.dart';
import '../widgets/doll_widgets.dart';
import 'collection_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isSigningIn = false;
  bool _showStats = false;

  @override
  Widget build(BuildContext context) {
    final user = authService.currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<ProfileSetupStatus>(
          stream: profileSetupRepository.watch(user.uid),
          builder: (context, profileSetupSnap) {
            final setupStatus = profileSetupSnap.data;
            final avatarId = setupStatus?.avatarId ?? '';
            final frameColor = setupStatus?.avatarFrameColor ?? '';

            final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
            return ListView(
              key: const PageStorageKey('profile_scroll'),
              padding: EdgeInsets.zero,
              children: [
                // Cover Photo Stack
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    buildCoverPhoto(context, setupStatus?.coverId,
                        isPro: setupStatus?.isPro == true),
                    Positioned(
                      top: 80,
                      left: 16,
                      child: InkWell(
                        onTap: () => showAvatarStudioModal(context, user.uid),
                        borderRadius: BorderRadius.circular(38),
                        child: buildAvatarHelper(context, avatarId, frameColor,
                            size: 76),
                      ),
                    ),
                    Positioned(
                      bottom: -15,
                      right: 16,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _showStats = !_showStats;
                          });
                        },
                        icon: Icon(
                          _showStats
                              ? Icons.insights_rounded
                              : Icons.bar_chart_rounded,
                          color: const Color(0xFFFFCC00),
                          size: 15,
                        ),
                        label: Text(
                          tr ? 'Profil İstatistiği' : 'Profile Stats',
                          style: const TextStyle(
                            color: Color(0xFFFFCC00),
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Color(0xFFFFCC00), width: 1.2),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .surface
                              .withOpacity(0.9),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 45),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      AccountSummaryCard(
                        displayName: user.displayName,
                        email: user.email,
                        onSignOut: _handleSignOut,
                        avatarId: avatarId,
                        frameColor: frameColor,
                        selectedBadge: setupStatus?.selectedBadge ?? '',
                      ),
                      const SizedBox(height: 8),
                      _buildCoinWallet(context, setupStatus?.coins ?? 20),
                      const SizedBox(height: 8),
                      // Connections stats row
                      StreamBuilder<List<AppUser>>(
                        stream: socialRepository.watchFriendsList(user.uid),
                        builder: (context, friendsSnap) {
                          final friendsCount = friendsSnap.data?.length ?? 0;
                          return StreamBuilder<List<AppUser>>(
                            stream:
                                socialRepository.watchFollowingList(user.uid),
                            builder: (context, followingSnap) {
                              final followingCount =
                                  followingSnap.data?.length ?? 0;
                              return StreamBuilder<List<AppUser>>(
                                stream: socialRepository
                                    .watchFollowersList(user.uid),
                                builder: (context, followersSnap) {
                                  final followersCount =
                                      followersSnap.data?.length ?? 0;
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                        top: 4, bottom: 8),
                                    child: InkWell(
                                      onTap: () => showConnectionsModal(
                                          context, user.uid),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 10),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.4),
                                              width: 1.2),
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surface,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceEvenly,
                                          children: [
                                            _buildStatItem(
                                              context,
                                              label: tr ? 'Arkadaş' : 'Friends',
                                              value: friendsCount.toString(),
                                            ),
                                            Container(
                                                width: 1.2,
                                                height: 24,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                    .withOpacity(0.4)),
                                            _buildStatItem(
                                              context,
                                              label: tr ? 'Takip' : 'Following',
                                              value: followingCount.toString(),
                                            ),
                                            Container(
                                                width: 1.2,
                                                height: 24,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                    .withOpacity(0.4)),
                                            _buildStatItem(
                                              context,
                                              label:
                                                  tr ? 'Takipçi' : 'Followers',
                                              value: followersCount.toString(),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      ProfileSetupCard(userId: user.uid),
                      const SizedBox(height: 16),
                      if (_showStats) ...[
                        const ProfileStatsCard(),
                        const SizedBox(height: 16),
                        CollectionAnalyticsCard(userId: user.uid),
                        const SizedBox(height: 16),
                      ],
                      FeaturedShowcaseCard(userId: user.uid),
                      const SizedBox(height: 16),
                      const ProfileShowcaseCard(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context,
      {required String label, required String value}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color:
                isDark ? Colors.white : Theme.of(context).colorScheme.primary,
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white70 : Colors.black54,
            fontFamily: 'Outfit',
          ),
        ),
      ],
    );
  }

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

  Widget _buildCoinWallet(BuildContext context, int coins) {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => showProSubscriptionModal(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1230) : const Color(0xFFFAF2FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFFFFCC00).withOpacity(0.4), width: 1.2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.monetization_on_rounded,
                    color: Color(0xFFFFCC00), size: 20),
                const SizedBox(width: 4),
                const Icon(Icons.add_circle_outline_rounded,
                    color: Color(0xFFFFCC00), size: 14),
                const SizedBox(width: 6),
                Text(
                  tr ? 'Jeton Cüzdanım' : 'My Coin Wallet',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      fontFamily: 'Outfit'),
                ),
              ],
            ),
            Text(
              tr ? '$coins Jeton' : '$coins Coins',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                fontFamily: 'Outfit',
                color: Color(0xFFFFCC00),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSignOut() async {
    try {
      await authService.signOut();
      collectionEntriesNotifier.value = <CollectionEntry>[];
      reportsNotifier.value = <UserReport>[];
      if (mounted) {
        context.go('/');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t(context, 'signOutFailed')} $error')),
      );
    }
  }
}

class AccountSummaryCard extends StatelessWidget {
  const AccountSummaryCard({
    required this.displayName,
    required this.email,
    required this.onSignOut,
    this.avatarId = '',
    this.frameColor = '',
    this.selectedBadge = '',
    super.key,
  });

  final String? displayName;
  final String? email;
  final Future<void> Function() onSignOut;
  final String avatarId;
  final String frameColor;
  final String selectedBadge;

  @override
  Widget build(BuildContext context) {
    final title = displayName?.trim().isNotEmpty == true
        ? displayName!.trim()
        : t(context, 'collectorAccount');
    final subtitle = email?.trim().isNotEmpty == true
        ? email!.trim()
        : t(context, 'signedIn');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            buildAvatarHelper(context, avatarId, frameColor, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ),
                      if (selectedBadge.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        ProfileBadgeWidget(badgeId: selectedBadge),
                      ],
                    ],
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: AppLanguageScope.languageOf(context) == AppLanguage.tr
                  ? 'Ayarlar'
                  : 'Settings',
              child: buildGothicNeonIconButton(
                context: context,
                icon: Icons.settings_outlined,
                onPressed: () => context.push('/settings'),
                size: 20,
                padding: const EdgeInsets.all(6),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: t(context, 'signOut'),
              child: buildGothicNeonIconButton(
                context: context,
                icon: Icons.logout_rounded,
                onPressed: onSignOut,
                size: 20,
                padding: const EdgeInsets.all(6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileSetupCard extends StatefulWidget {
  const ProfileSetupCard({
    required this.userId,
    super.key,
  });

  final String userId;

  @override
  State<ProfileSetupCard> createState() => _ProfileSetupCardState();
}

class _ProfileSetupCardState extends State<ProfileSetupCard> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _birthYearController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _birthYearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ProfileSetupStatus>(
      stream: profileSetupRepository.watch(widget.userId),
      builder: (context, snapshot) {
        final status = snapshot.data;
        if (status?.isComplete == true) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${t(context, 'username')}: @${status!.username}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (status != null && _usernameController.text.isEmpty) {
          _usernameController.text = status.username;
        }
        if (status?.birthYear != null && _birthYearController.text.isEmpty) {
          _birthYearController.text = '${status!.birthYear}';
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t(context, 'completeProfileRequired'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(t(context, 'completeProfileBody')),
                  const SizedBox(height: 8),
                  Text(
                    t(context, 'usernameChangeWarning'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _usernameController,
                    maxLength: 15,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(fontFamily: 'Outfit'),
                    decoration: InputDecoration(
                      labelText: t(context, 'username'),
                      prefixText: '@',
                      helperText: t(context, 'usernameRules'),
                    ),
                    validator: (value) {
                      final username =
                          ProfileSetupRepository.normalizeUsername(value ?? '');
                      if (!ProfileSetupRepository.isValidUsername(username)) {
                        return t(context, 'usernameInvalid');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _birthYearController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    style: const TextStyle(fontFamily: 'Outfit'),
                    decoration: InputDecoration(
                      labelText: t(context, 'birthYear'),
                      helperText: t(context, 'ageRequirement'),
                    ),
                    validator: (value) {
                      final birthYear = int.tryParse(value ?? '');
                      final currentYear = DateTime.now().year;
                      if (birthYear == null ||
                          birthYear < 1900 ||
                          birthYear > currentYear) {
                        return t(context, 'birthYearInvalid');
                      }
                      if (ProfileSetupRepository.ageFromBirthYear(birthYear) <
                          ProfileSetupRepository.minAge) {
                        return t(context, 'ageTooYoung');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline_rounded),
                    label: Text(t(context, 'saveProfile')),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isSaving = true;
    });

    try {
      await profileSetupRepository.saveRequiredProfile(
        userId: widget.userId,
        username: _usernameController.text,
        birthYear: int.parse(_birthYearController.text),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(context, 'profileSaved'))),
      );
    } on UsernameTakenException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(context, 'usernameTaken'))),
      );
    } on UsernameChangeLockedException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(context, 'usernameChangeLocked'))),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t(context, 'profileSaveFailed')} $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}

class ProfileStatsCard extends StatelessWidget {
  const ProfileStatsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<CollectionEntry>>(
      valueListenable: collectionEntriesNotifier,
      builder: (context, collectionEntries, _) {
        return ValueListenableBuilder<List<CatalogEntry>>(
          valueListenable: catalogEntriesNotifier,
          builder: (context, catalogEntries, _) {
            return ValueListenableBuilder<Map<String, List<AppComment>>>(
              valueListenable: commentsNotifier,
              builder: (context, commentsByTarget, _) {
                final commentCount = commentsByTarget.values.fold<int>(
                  0,
                  (total, comments) => total + comments.length,
                );

                return ValueListenableBuilder<List<UserReport>>(
                  valueListenable: reportsNotifier,
                  builder: (context, reports, _) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t(context, 'profileStats'),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: GothicStatButton(
                                    icon: Icons.inventory_2_outlined,
                                    label: t(context, 'collection'),
                                    value: '${collectionEntries.length}',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: GothicStatButton(
                                    icon: Icons.search_rounded,
                                    label: t(context, 'catalog'),
                                    value: '${catalogEntries.length}',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: GothicStatButton(
                                    icon: Icons.chat_bubble_outline_rounded,
                                    label: t(context, 'comments'),
                                    value: '$commentCount',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: GothicStatButton(
                                    icon: Icons.flag_outlined,
                                    label: t(context, 'report'),
                                    value: '${reports.length}',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class ProfileShowcaseCard extends StatelessWidget {
  const ProfileShowcaseCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<CollectionEntry>>(
      valueListenable: collectionEntriesNotifier,
      builder: (context, entries, _) {
        if (entries.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t(context, 'profileShowcaseTitle'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(t(context, 'profileShowcaseEmpty')),
                ],
              ),
            ),
          );
        }

        final owned =
            entries.where((e) => e.status == CollectionStatus.owned).toList();
        final wanted =
            entries.where((e) => e.status == CollectionStatus.wanted).toList();
        final trade =
            entries.where((e) => e.status == CollectionStatus.trade).toList();
        final selling =
            entries.where((e) => e.status == CollectionStatus.selling).toList();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: DefaultTabController(
              length: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t(context, 'profileShowcaseTitle'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    indicatorColor: Theme.of(context).colorScheme.primary,
                    labelColor: Theme.of(context).colorScheme.primary,
                    unselectedLabelColor: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                    tabs: [
                      Tab(text: t(context, 'owned')),
                      Tab(text: t(context, 'wanted')),
                      Tab(text: t(context, 'trade')),
                      Tab(text: t(context, 'selling')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 320,
                    child: TabBarView(
                      children: [
                        CollectionCategoryTab(entries: owned),
                        CollectionCategoryTab(entries: wanted),
                        CollectionCategoryTab(entries: trade),
                        CollectionCategoryTab(entries: selling),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class FeaturedShowcaseCard extends StatelessWidget {
  const FeaturedShowcaseCard({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context) {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMe = authService.currentUser?.uid == userId;

    return StreamBuilder<ProfileSetupStatus>(
      stream: profileSetupRepository.watch(userId),
      builder: (context, userSnap) {
        if (!userSnap.hasData) return const SizedBox.shrink();
        final featuredIds = userSnap.data!.featuredEntryIds;

        if (featuredIds.isEmpty) {
          if (!isMe) return const SizedBox.shrink();
          final isPro =
              userSnap.data?.isPro == true || userSnap.data?.role == 'admin';
          final maxShowcase = isPro ? '15' : '3';
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr ? 'Öne Çıkan Vitrin' : 'Featured Showcase',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr
                        ? 'Vitrininiz boş. Koleksiyonunuzdaki favori bebeklerinizin detay sayfasından yıldız simgesine tıklayarak vitrinize ekleyebilirsiniz! (Maksimum $maxShowcase bebek)'
                        : 'Your showcase is empty. Tap the star icon on your favorite dolls\' detail pages to feature them here! (Max $maxShowcase dolls)',
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Outfit',
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final isPro =
            userSnap.data?.isPro == true || userSnap.data?.role == 'admin';
        final maxShowText = isPro ? (tr ? 'Sınırsız' : 'Unlimited') : '30';

        return FutureBuilder<List<CollectionEntry>>(
          future: collectionRepository.listForUser(userId),
          builder: (context, collectionSnap) {
            if (!collectionSnap.hasData) {
              return const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final allEntries = collectionSnap.data!;
            final featuredEntries = allEntries
                .where((entry) => featuredIds.contains(entry.id))
                .toList();

            if (featuredEntries.isEmpty) return const SizedBox.shrink();

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          tr ? 'Öne Çıkan Vitrin' : 'Featured Showcase',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: const Color(0xFFFFCC00), width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: Color(0xFFFFCC00), size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '${featuredEntries.length} / $maxShowText',
                                style: const TextStyle(
                                  color: Color(0xFFFFCC00),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Outfit',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 175,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: featuredEntries.length,
                        itemBuilder: (context, index) {
                          final entry = featuredEntries[index];
                          final item = findCatalogEntry(entry.itemId);
                          return GestureDetector(
                            onTap: () {
                              if (isMe) {
                                context.go('/c/${entry.id}?from=profile');
                              } else {
                                context.go(
                                    '/c/${entry.id}?from=public_profile&userId=$userId');
                              }
                            },
                            child: Container(
                              width: 110,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF160E22)
                                    : const Color(0xFFFAF6FC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      const Color(0xFFFFCC00).withOpacity(0.4),
                                  width: 1.5,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          DollImage(
                                            imageUrl: item.primaryImageUrl,
                                            label: entryName(context, item),
                                          ),
                                          Positioned(
                                            top: 4,
                                            right: 4,
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: const BoxDecoration(
                                                color: Colors.black54,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.star_rounded,
                                                color: Color(0xFFFFCC00),
                                                size: 14,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(6.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            entryName(context, item),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              fontFamily: 'Outfit',
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            conditionLabel(
                                                context, entry.condition),
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.white60
                                                  : Colors.black54,
                                              fontSize: 9,
                                              fontFamily: 'Outfit',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class CollectionAnalyticsCard extends StatelessWidget {
  const CollectionAnalyticsCard({required this.userId, super.key});

  final String userId;

  String _formatCharName(String id) {
    return switch (id) {
      'draculaura' => 'Draculaura',
      'clawdeen' => 'Clawdeen Wolf',
      'frankie' => 'Frankie Stein',
      'cleo' => 'Cleo de Nile',
      'lagoona' => 'Lagoona Blue',
      'ghoulia' => 'Ghoulia Yelps',
      _ => id.isNotEmpty ? '${id[0].toUpperCase()}${id.substring(1)}' : '',
    };
  }

  Widget _buildLockedPremiumCard(BuildContext context, bool tr, bool isDark) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.lock_outline_rounded,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              tr
                  ? 'Koleksiyon İstatistikleri (Pro)'
                  : 'Collection Analytics (Pro)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr
                  ? 'Kutulu/Kutusuz oranları, set tamamlanma yüzdeleri ve gelişmiş kategori dağılım grafiklerini görmek için DollDex Pro sürümüne yükseltin!'
                  : 'Upgrade to DollDex Pro to view boxed/unboxed ratios, set completion rates, and advanced category distribution charts!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'Outfit',
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => showProSubscriptionModal(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: Text(
                tr ? 'Pro Avantajlarını Gör' : 'View Pro Benefits',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final viewerId = authService.currentUser?.uid;

    return StreamBuilder<ProfileSetupStatus>(
      stream: profileSetupRepository.watch(userId),
      builder: (context, userSnap) {
        if (!userSnap.hasData) return const SizedBox.shrink();
        final user = userSnap.data!;
        final isOwnerPro = user.isPro || user.role == 'admin';

        final isMe = userId == (viewerId ?? 'local-user');

        if (isMe) {
          if (!isOwnerPro) {
            return _buildLockedPremiumCard(context, tr, isDark);
          }
          return ValueListenableBuilder<List<CollectionEntry>>(
            valueListenable: collectionEntriesNotifier,
            builder: (context, collectionEntries, _) {
              return _buildContent(context, collectionEntries, isDark, tr);
            },
          );
        } else {
          // If the profile owner is Pro, everyone can see their stats
          if (isOwnerPro) {
            return FutureBuilder<List<CollectionEntry>>(
              future: collectionRepository.listPublicForUser(userId),
              builder: (context, collectionSnap) {
                final collectionEntries = collectionSnap.data ?? [];
                return _buildContent(context, collectionEntries, isDark, tr);
              },
            );
          }

          if (viewerId == null) {
            return _buildLockedPremiumCard(context, tr, isDark);
          }

          // If owner is not Pro, check if the viewing user is Pro
          return StreamBuilder<ProfileSetupStatus>(
            stream: profileSetupRepository.watch(viewerId),
            builder: (context, viewerSnap) {
              if (!viewerSnap.hasData) return const SizedBox.shrink();
              final viewer = viewerSnap.data!;
              final isViewerPro = viewer.isPro || viewer.role == 'admin';

              if (!isViewerPro) {
                return _buildLockedPremiumCard(context, tr, isDark);
              }

              return FutureBuilder<List<CollectionEntry>>(
                future: collectionRepository.listPublicForUser(userId),
                builder: (context, collectionSnap) {
                  final collectionEntries = collectionSnap.data ?? [];
                  return _buildContent(context, collectionEntries, isDark, tr);
                },
              );
            },
          );
        }
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<CollectionEntry> collectionEntries,
    bool isDark,
    bool tr,
  ) {
    if (collectionEntries.isEmpty) {
      return const SizedBox.shrink();
    }

    final boxedCount = collectionEntries
        .where((e) => e.condition == CollectionCondition.boxed)
        .length;
    final totalCount = collectionEntries.length;
    final boxedPct = totalCount > 0 ? boxedCount / totalCount : 0.0;
    final unboxedPct = 1.0 - boxedPct;

    final totalCatalog = catalogEntriesNotifier.value;
    int dollCount = 0;
    int petCount = 0;
    int accCount = 0;

    for (final entry in collectionEntries) {
      final cat = totalCatalog.firstWhere(
        (c) => c.id == entry.itemId,
        orElse: () => const CatalogEntry(
          id: '',
          name: '',
          type: CatalogItemType.doll,
          subtitle: '',
          imageUrls: [],
          averagePrice: 1200.0,
        ),
      );
      if (cat.id.isNotEmpty) {
        if (cat.type == CatalogItemType.doll) dollCount++;
        if (cat.type == CatalogItemType.pet) petCount++;
        if (cat.type == CatalogItemType.accessory) accCount++;
      }
    }

    final charMap = <String, List<String>>{};
    for (final cat in totalCatalog) {
      for (final charId in cat.characterIds) {
        charMap.putIfAbsent(charId, () => []).add(cat.id);
      }
    }
    final ownedItemIds = collectionEntries.map((e) => e.itemId).toSet();
    final charProgress = <String, double>{};
    charMap.forEach((charId, itemIds) {
      final ownedCount =
          itemIds.where((id) => ownedItemIds.contains(id)).length;
      if (ownedCount > 0) {
        charProgress[charId] = ownedCount / itemIds.length;
      }
    });

    final sortedChars = charProgress.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topChars = sortedChars.take(3).toList();

    // Realistic Value Calculation
    double estValue = 0;
    for (final entry in collectionEntries) {
      if (entry.status == CollectionStatus.wanted) continue;
      final cat = totalCatalog.firstWhere(
        (c) => c.id == entry.itemId,
        orElse: () => const CatalogEntry(
          id: '',
          name: '',
          type: CatalogItemType.doll,
          subtitle: '',
          imageUrls: [],
          averagePrice: 1200.0,
        ),
      );
      final basePrice = cat.id.isNotEmpty ? cat.averagePrice : 1200.0;

      double multiplier = 1.0;
      switch (entry.condition) {
        case CollectionCondition.boxed:
          multiplier = 1.5;
          break;
        case CollectionCondition.unboxed:
          multiplier = 0.7;
          break;
        case CollectionCondition.complete:
          multiplier = 1.0;
          break;
        case CollectionCondition.incomplete:
          multiplier = 0.5;
          break;
        case CollectionCondition.damaged:
          multiplier = 0.3;
          break;
      }
      estValue += (basePrice * multiplier * entry.quantity);
    }

    final formattedVal = '₺' +
        estValue.toInt().toString().replaceAllMapped(
              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
              (Match m) => '${m[1]}.',
            );

    String charAnalysisText = '';
    if (topChars.isNotEmpty) {
      final topCharName = _formatCharName(topChars.first.key);
      final topPct = (topChars.first.value * 100).toStringAsFixed(0);
      charAnalysisText = tr
          ? "Koleksiyonunuzda en baskın karakter $topCharName (%$topPct tamamlanma). "
          : "Your most dominant character is $topCharName ($topPct% completed). ";
    }
    final conditionText = boxedPct > 0.4
        ? (tr
            ? "Kutulu korumaya (NIB) ağırlık veriyorsunuz."
            : "You heavily prefer Mint-In-Box (NIB) preservation.")
        : (tr
            ? "Bebekleri kutusundan çıkarıp sergilemeyi seviyorsunuz."
            : "You prefer unboxing and displaying your dolls.");
    final insights = "$charAnalysisText$conditionText";

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ).createShader(bounds),
                  child: const Icon(Icons.workspace_premium_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 8),
                Text(
                  tr ? 'Profil İstatistiği' : 'Profile Statistics',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Outfit',
                    letterSpacing: 1.2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Estimated Value Gauge
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.08),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    tr
                        ? 'TAHMİNİ KOLEKSİYON DEĞERİ'
                        : 'ESTIMATED COLLECTION VALUE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                      letterSpacing: 1.0,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formattedVal,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Outfit',
                      color: Theme.of(context).colorScheme.primary,
                      shadows: [
                        Shadow(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr
                        ? '*Mevcut kondisyon ve katalog ortalamasına göre tahmini hesaptır.'
                        : '*Estimated value calculated based on current conditions and averages.',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.white38 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // KPI Grid Row 1
            Row(
              children: [
                Expanded(
                  child: _buildKPICard(
                    context,
                    icon: Icons.inventory_2_outlined,
                    label: tr ? 'Toplam Öğe' : 'Total Items',
                    value: '$totalCount ${tr ? 'Adet' : 'Items'}',
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildKPICard(
                    context,
                    icon: Icons.auto_awesome_outlined,
                    label: tr ? 'Koleksiyoner Skoru' : 'Collector Score',
                    value: '${totalCount * 125 + boxedCount * 75} XP',
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // KPI Grid Row 2
            Row(
              children: [
                Expanded(
                  child: _buildKPICard(
                    context,
                    icon: Icons.diamond_outlined,
                    label: tr ? 'Nadir & Özel' : 'Rare & Special',
                    value:
                        '${(totalCount * 0.15).ceil()} ${tr ? 'Parça' : 'Pcs'}',
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.85),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildKPICard(
                    context,
                    icon: Icons.health_and_safety_outlined,
                    label: tr ? 'Ort. Kondisyon' : 'Avg. Condition',
                    value: boxedPct > 0.4
                        ? (tr ? 'Kutulu (MIB)' : 'MIB / Pristine')
                        : (tr ? 'Çok İyi (EX)' : 'Very Good'),
                    color: Theme.of(context)
                        .colorScheme
                        .secondary
                        .withOpacity(0.85),
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            Text(
              tr
                  ? 'Koleksiyon Oranları & Sağlığı'
                  : 'Collection Health & Ratios',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  fontFamily: 'Outfit'),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                NeonPieChart(
                  percentage: boxedPct,
                  label: tr ? 'Kutulu MIB' : 'Boxed MIB',
                  color: Theme.of(context).colorScheme.primary,
                ),
                NeonPieChart(
                  percentage: unboxedPct,
                  label: tr ? 'Açılmış' : 'Unboxed',
                  color: Theme.of(context).colorScheme.secondary,
                ),
                NeonPieChart(
                  percentage: totalCatalog.isNotEmpty
                      ? (totalCount / totalCatalog.length).clamp(0.0, 1.0)
                      : 0.0,
                  label: tr ? 'Katalog Oranı' : 'Catalog Comp.',
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                ),
              ],
            ),
            const Divider(height: 28),
            Text(
              tr ? 'Kategori Dağılımı' : 'Category Distribution',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  fontFamily: 'Outfit'),
            ),
            const SizedBox(height: 8),
            NeonBarChart(
              label: tr ? 'Bebekler (Dolls)' : 'Dolls',
              count: dollCount,
              total: totalCount,
              color: Theme.of(context).colorScheme.primary,
            ),
            NeonBarChart(
              label: tr ? 'Evcil Hayvanlar (Pets)' : 'Pets',
              count: petCount,
              total: totalCount,
              color: Theme.of(context).colorScheme.secondary,
            ),
            NeonBarChart(
              label: tr ? 'Aksesuarlar (Accs)' : 'Accessories',
              count: accCount,
              total: totalCount,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
            ),
            if (topChars.isNotEmpty) ...[
              const Divider(height: 28),
              Text(
                tr
                    ? 'Karakter Tamamlanma Oranları'
                    : 'Character Completion Rates',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    fontFamily: 'Outfit'),
              ),
              const SizedBox(height: 10),
              for (final char in topChars)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatCharName(char.key),
                            style: const TextStyle(
                                fontSize: 11, fontFamily: 'Outfit'),
                          ),
                          Text(
                            '${(char.value * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Outfit'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: char.value,
                          minHeight: 6,
                          backgroundColor: Colors.white10,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const Divider(height: 28),
            // Collector Insights Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.psychology_outlined,
                      color: Theme.of(context).colorScheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      insights,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontFamily: 'Outfit',
                        color: isDark ? Colors.white70 : Colors.black87,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKPICard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF160E22) : const Color(0xFFFAF6FC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontFamily: 'Outfit',
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NeonPieChart extends StatelessWidget {
  const NeonPieChart({
    required this.percentage,
    required this.label,
    required this.color,
    super.key,
  });

  final double percentage;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: 1.0,
                strokeWidth: 5,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).dividerColor,
                ),
              ),
              CircularProgressIndicator(
                value: percentage,
                strokeWidth: 5,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
              Center(
                child: Text(
                  '${(percentage * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
        ),
      ],
    );
  }
}

class NeonBarChart extends StatelessWidget {
  const NeonBarChart({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
    super.key,
  });

  final String label;
  final int count;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final double pct = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, fontFamily: 'Outfit'),
              ),
              Text(
                '$count / $total',
                style: const TextStyle(
                    fontSize: 11, fontFamily: 'Outfit', color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}
