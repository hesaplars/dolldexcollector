import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

import '../core/app_language.dart';
import 'public_profile_screen.dart';

class UsernameProfileLoader extends StatefulWidget {
  const UsernameProfileLoader({
    required this.username,
    super.key,
  });

  final String username;

  @override
  State<UsernameProfileLoader> createState() => _UsernameProfileLoaderState();
}

class _UsernameProfileLoaderState extends State<UsernameProfileLoader> {
  late final Future<String?> _userIdFuture;

  @override
  void initState() {
    super.initState();
    _userIdFuture = _lookupUserId();
  }

  Future<String?> _lookupUserId() async {
    final normalized = widget.username.toLowerCase().trim();
    try {
      // 1. Direct doc check in usernames
      final docSnap = await FirebaseFirestore.instance
          .collection('usernames')
          .doc(normalized)
          .get();
      if (docSnap.exists) {
        final userId = docSnap.data()?['userId'] as String?;
        if (userId != null && userId.isNotEmpty) {
          return userId;
        }
      }
      // 2. Query users fallback
      final querySnap = await FirebaseFirestore.instance
          .collection('users')
          .where('usernameLower', isEqualTo: normalized)
          .limit(1)
          .get();
      if (querySnap.docs.isNotEmpty) {
        return querySnap.docs.first.id;
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<String?>(
      future: _userIdFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: isDark ? const Color(0xFFEC008C) : Colors.pink,
              ),
            ),
          );
        }

        final userId = snapshot.data;
        if (userId != null) {
          return PublicProfileScreen(userId: userId);
        }

        // Not found screen
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/');
                }
              },
            ),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFEC008C).withOpacity(0.1),
                      border: Border.all(
                        color: const Color(0xFFEC008C).withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.person_off_rounded,
                      size: 64,
                      color: Color(0xFFEC008C),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    tr ? 'Kullanıcı Bulunamadı' : 'User Not Found',
                    style: const TextStyle(
                      fontFamily: 'Cinzel',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr
                        ? '@${widget.username} adına kayıtlı bir kullanıcı bulunamadı. Kullanıcı adı silinmiş veya değiştirilmiş olabilir.'
                        : 'No user found with username @${widget.username}. The username might have been changed or deleted.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEC008C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: () {
                      context.go('/');
                    },
                    icon: const Icon(Icons.home_rounded),
                    label: Text(tr ? 'Ana Sayfa' : 'Home'),
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
