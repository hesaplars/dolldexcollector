import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../main.dart';
import '../core/app_helpers.dart';
import '../core/app_language.dart';
import '../widgets/doll_widgets.dart';
import '../catalog/catalog_models.dart';
import '../auth/auth_service.dart';

class LegalConsentScreen extends StatefulWidget {
  const LegalConsentScreen({super.key});

  @override
  State<LegalConsentScreen> createState() => _LegalConsentScreenState();
}

class _LegalConsentScreenState extends State<LegalConsentScreen> {
  bool _accepted = false;
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn(BuildContext context) async {
    if (!_accepted || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
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
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  tr
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(context, 'signInSuccess'))),
        );
        context.go('/');
      }
    } on AuthCancelledException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(context, 'signInCancelled'))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(context, 'signInError') + ': $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (authService.currentUser != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go('/');
        }
      });
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final theme = Theme.of(context);
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final secondaryColor = theme.colorScheme.secondary;

    final cardColor = theme.cardTheme.color ??
        (isDark ? DollDexTheme.darkPanel : DollDexTheme.panel);
    final textColor = theme.textTheme.bodyMedium?.color ??
        (isDark ? Colors.white70 : Colors.black87);

    Color borderColor = secondaryColor.withValues(alpha: 0.3);
    if (theme.cardTheme.shape is RoundedRectangleBorder) {
      final borderSide = (theme.cardTheme.shape as RoundedRectangleBorder).side;
      if (borderSide.color != Colors.transparent &&
          borderSide.color != Colors.black) {
        borderColor = borderSide.color;
      }
    }

    return PageShell(
      title: tr ? 'Onay ve Giriş' : 'Consent & Sign In',
      subtitle: t(context, 'legalSubtitle'),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            elevation: 8,
            color: cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(
                color: borderColor,
                width: 1.2,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: DefaultTabController(
                length: 2,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      tr
                          ? 'Google ile giriş yapmadan önce lütfen aşağıdaki sözleşmeleri okuyup onaylayın.'
                          : 'Please read and accept the agreements below before signing in with Google.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: textColor.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TabBar(
                      labelColor: primaryColor,
                      unselectedLabelColor: textColor.withValues(alpha: 0.5),
                      indicatorColor: secondaryColor,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      tabs: [
                        Tab(text: t(context, 'termsOfUse')),
                        Tab(text: t(context, 'privacyPolicy')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 270,
                      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('configs')
                            .doc('legal_and_info')
                            .snapshots(),
                        builder: (context, snapshot) {
                          String terms = t(context, 'termsBody');
                          String privacy = t(context, 'privacyBody');

                          if (snapshot.hasData && snapshot.data!.exists) {
                            final data = snapshot.data!.data();
                            if (data != null) {
                              final dbTerms = tr
                                  ? data['termsBody_tr'] as String?
                                  : data['termsBody_en'] as String?;
                              final dbPrivacy = tr
                                  ? data['privacyBody_tr'] as String?
                                  : data['privacyBody_en'] as String?;

                              if (dbTerms != null && dbTerms.trim().isNotEmpty) {
                                terms = dbTerms;
                              }
                              if (dbPrivacy != null && dbPrivacy.trim().isNotEmpty) {
                                privacy = dbPrivacy;
                              }
                            }
                          }

                          return TabBarView(
                            children: [
                              _buildScrollableText(context, terms),
                              _buildScrollableText(context, privacy),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Theme(
                      data: theme.copyWith(
                        unselectedWidgetColor:
                            isDark ? Colors.white30 : Colors.black38,
                      ),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _accepted = !_accepted;
                          });
                        },
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Checkbox(
                              value: _accepted,
                              activeColor: primaryColor,
                              checkColor: Colors.white,
                              onChanged: (val) {
                                setState(() {
                                  _accepted = val ?? false;
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                tr
                                    ? 'Gizlilik Sözleşmesi ve Kullanım Koşulları\'nı okudum ve kabul ediyorum.'
                                    : 'I read and accept the Privacy Policy and Terms of Use.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: textColor.withValues(alpha: 0.85),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: _accepted && !_isLoading
                            ? LinearGradient(
                                colors: [primaryColor, const Color(0xFFFF7A1F)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              )
                            : LinearGradient(
                                colors: [
                                  isDark
                                      ? Colors.grey.shade800
                                      : Colors.grey.shade300,
                                  isDark
                                      ? Colors.grey.shade900
                                      : Colors.grey.shade400,
                                ],
                              ),
                        boxShadow: _accepted && !_isLoading
                            ? [
                                BoxShadow(
                                  color: primaryColor.withValues(alpha: 0.28),
                                  blurRadius: 12,
                                  offset: const Offset(0, 5),
                                ),
                              ]
                            : null,
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _accepted && !_isLoading
                            ? () => _handleGoogleSignIn(context)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        icon: _isLoading
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.8,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.login_rounded,
                                color: Colors.white, size: 18),
                        label: Text(
                          t(context, 'continueGoogle'),
                          style: TextStyle(
                            color: _accepted && !_isLoading
                                ? Colors.white
                                : (isDark ? Colors.white30 : Colors.black26),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScrollableText(BuildContext context, String text) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final boxColor = isDark
        ? theme.scaffoldBackgroundColor.withValues(alpha: 0.6)
        : DollDexTheme.mist;

    final textColor = (theme.textTheme.bodyMedium?.color ??
            (isDark ? Colors.white70 : Colors.black87))
        .withValues(alpha: 0.7);
    final borderColor = isDark ? Colors.white10 : Colors.black12;

    return Container(
      decoration: BoxDecoration(
        color: boxColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
          width: 0.8,
        ),
      ),
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 12.5,
              height: 1.55,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
