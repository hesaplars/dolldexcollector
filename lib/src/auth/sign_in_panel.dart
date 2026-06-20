import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/app_language.dart';

class SignInPanel extends StatefulWidget {
  const SignInPanel({
    required this.onGooglePressed,
    this.isLoading = false,
    super.key,
  });

  final VoidCallback onGooglePressed;
  final bool isLoading;

  @override
  State<SignInPanel> createState() => _SignInPanelState();
}

class _SignInPanelState extends State<SignInPanel> {
  bool _acceptedPrivacy = false;
  bool _acceptedTerms = false;

  bool get _canContinue {
    return _acceptedPrivacy && _acceptedTerms && !widget.isLoading;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFEC008C),
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEC008C).withOpacity(0.3),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                  color: const Color(0xFF160E22),
                ),
                child: Center(
                  child: ShaderMask(
                    shaderCallback: (bounds) {
                      return const LinearGradient(
                        colors: [Color(0xFFEC008C), Color(0xFF00FFCC)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds);
                    },
                    child: const Icon(
                      Icons.face_3_outlined,
                      size: 28,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              t(context, 'collectorAccount'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              t(context, 'signInBody'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _acceptedPrivacy,
              onChanged: (value) {
                setState(() {
                  _acceptedPrivacy = value ?? false;
                });
              },
              title: Text(t(context, 'acceptPrivacy')),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _acceptedTerms,
              onChanged: (value) {
                setState(() {
                  _acceptedTerms = value ?? false;
                });
              },
              title: Text(t(context, 'acceptTerms')),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => context.push('/privacy'),
                  child: Text(t(context, 'privacyPolicy')),
                ),
                TextButton(
                  onPressed: () => context.push('/terms'),
                  child: Text(t(context, 'termsOfUse')),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: _canContinue
                    ? const LinearGradient(
                        colors: [Color(0xFFEC008C), Color(0xFF7B2CBF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(
                        colors: [Colors.grey.shade800, Colors.grey.shade900],
                      ),
                boxShadow: _canContinue
                    ? [
                        BoxShadow(
                          color: const Color(0xFFEC008C).withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: ElevatedButton.icon(
                onPressed: _canContinue ? widget.onGooglePressed : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                icon: widget.isLoading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.login_rounded, color: Colors.white),
                label: Text(
                  t(context, 'continueGoogle'),
                  style: TextStyle(
                    color: _canContinue ? Colors.white : Colors.white54,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
