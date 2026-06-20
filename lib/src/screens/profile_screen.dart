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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ValueListenableBuilder<bool>(
          valueListenable: firebaseReadyNotifier,
          builder: (context, firebaseReady, _) {
            if (!firebaseReady) {
              return PageShell(
                title: t(context, 'profile'),
                subtitle: t(context, 'profileSubtitle'),
                child: SignInPanel(
                  onGooglePressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(t(context, 'signInNeedsFirebase'))),
                    );
                  },
                ),
              );
            }

            return StreamBuilder<User?>(
              stream: authService.authStateChanges,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return PageShell(
                    title: t(context, 'profile'),
                    subtitle: t(context, 'profileSubtitle'),
                    child: SignInPanel(
                      isLoading: _isSigningIn,
                      onGooglePressed: _handleGoogleSignIn,
                    ),
                  );
                }

                final user = snapshot.data;
                if (user == null) {
                  return PageShell(
                    title: t(context, 'profile'),
                    subtitle: t(context, 'profileSubtitle'),
                    child: SignInPanel(
                      isLoading: _isSigningIn,
                      onGooglePressed: _handleGoogleSignIn,
                    ),
                  );
                }

                return StreamBuilder<ProfileSetupStatus>(
                  stream: profileSetupRepository.watch(user.uid),
                  builder: (context, profileSetupSnap) {
                    final setupStatus = profileSetupSnap.data;
                    final avatarId = setupStatus?.avatarId ?? '';
                    final frameColor = setupStatus?.avatarFrameColor ?? '';

                    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
                    return ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        // Cover Photo Stack
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            buildCoverPhoto(context, setupStatus?.coverId, isPro: setupStatus?.isPro == true),
                            Positioned(
                              top: 80,
                              left: 16,
                              child: InkWell(
                                onTap: () => showAvatarStudioModal(context, user.uid),
                                borderRadius: BorderRadius.circular(38),
                                child: buildAvatarHelper(avatarId, frameColor, size: 76),
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
                              ),
                              const SizedBox(height: 8),
                              // Connections stats row
                              StreamBuilder<List<AppUser>>(
                                stream: socialRepository.watchFriendsList(user.uid),
                                builder: (context, friendsSnap) {
                                  final friendsCount = friendsSnap.data?.length ?? 0;
                                  return StreamBuilder<List<AppUser>>(
                                    stream: socialRepository.watchFollowingList(user.uid),
                                    builder: (context, followingSnap) {
                                      final followingCount = followingSnap.data?.length ?? 0;
                                      return StreamBuilder<List<AppUser>>(
                                        stream: socialRepository.watchFollowersList(user.uid),
                                        builder: (context, followersSnap) {
                                          final followersCount = followersSnap.data?.length ?? 0;
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 4, bottom: 8),
                                            child: InkWell(
                                              onTap: () => showConnectionsModal(context, user.uid),
                                              borderRadius: BorderRadius.circular(12),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: const Color(0xFFEC008C).withOpacity(0.4), width: 1.2),
                                                  color: Theme.of(context).brightness == Brightness.dark
                                                      ? const Color(0xFF171026)
                                                      : const Color(0xFFFAF2FF),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                  children: [
                                                    _buildStatItem(
                                                      context,
                                                      label: tr ? 'Arkadaş' : 'Friends',
                                                      value: friendsCount.toString(),
                                                    ),
                                                    Container(width: 1.2, height: 24, color: const Color(0xFFEC008C).withOpacity(0.4)),
                                                    _buildStatItem(
                                                      context,
                                                      label: tr ? 'Takip' : 'Following',
                                                      value: followingCount.toString(),
                                                    ),
                                                    Container(width: 1.2, height: 24, color: const Color(0xFFEC008C).withOpacity(0.4)),
                                                    _buildStatItem(
                                                      context,
                                                      label: tr ? 'Takipçi' : 'Followers',
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
                              const ProfileStatsCard(),
                              const SizedBox(height: 16),
                              const ProfileShowcaseCard(),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, {required String label, required String value}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFFEC008C),
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
      final userCredential = await authService.signInWithGoogle();
      final newUser = userCredential.user;
      if (newUser != null) {
        final localEntries = collectionEntriesNotifier.value
            .where((entry) => entry.userId == 'local-user')
            .toList();
        if (localEntries.isNotEmpty) {
          for (final localEntry in localEntries) {
            final migratedEntry = CollectionEntry(
              id: '${newUser.uid}-${localEntry.itemId}',
              userId: newUser.uid,
              itemId: localEntry.itemId,
              status: localEntry.status,
              condition: localEntry.condition,
              quantity: localEntry.quantity,
              notes: localEntry.notes,
              isPublic: localEntry.isPublic,
            );
            await collectionRepository.save(migratedEntry);
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLanguageScope.languageOf(context) == AppLanguage.tr
                      ? '${localEntries.length} parça hesabınıza aktarıldı!'
                      : '${localEntries.length} items migrated to your account!',
                ),
              ),
            );
          }
        }
      }
      await loadCollectionForCurrentUser();
      await loadReports();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(context, 'signInSuccess'))),
      );
    } on AuthCancelledException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(context, 'signInCancelled'))),
      );
    } on StateError {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(context, 'signInNeedsFirebase'))),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t(context, 'signInFailed')} $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
    }
  }

  Future<void> _handleSignOut() async {
    try {
      await authService.signOut();
      collectionEntriesNotifier.value = <CollectionEntry>[];
      reportsNotifier.value = <UserReport>[];
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
    super.key,
  });

  final String? displayName;
  final String? email;
  final Future<void> Function() onSignOut;
  final String avatarId;
  final String frameColor;

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
            buildAvatarHelper(avatarId, frameColor, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
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
              message: AppLanguageScope.languageOf(context) == AppLanguage.tr ? 'Ayarlar' : 'Settings',
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

        final owned = entries.where((e) => e.status == CollectionStatus.owned).toList();
        final wanted = entries.where((e) => e.status == CollectionStatus.wanted).toList();
        final trade = entries.where((e) => e.status == CollectionStatus.trade).toList();
        final selling = entries.where((e) => e.status == CollectionStatus.selling).toList();

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
                    unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
