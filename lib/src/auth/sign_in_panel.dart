import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:go_router/go_router.dart';

import '../core/app_language.dart';
import '../widgets/doll_widgets.dart';

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
  bool _acceptedTermsAndPrivacy = false;

  bool get _canContinue {
    return _acceptedTermsAndPrivacy && !widget.isLoading;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Card(
          elevation: 8,
          color: isDark ? DollDexTheme.darkPanel : DollDexTheme.panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: isDark ? DollDexTheme.darkLine : DollDexTheme.line,
              width: 1.2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: DollDexTheme.mist,
                    border: Border.all(
                        color: isDark
                            ? DollDexTheme.darkLine.withValues(alpha: 0.7)
                            : DollDexTheme.line.withValues(alpha: 0.7)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.12),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.face_3_outlined,
                    size: 34,
                    color: DollDexTheme.teal,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  t(context, 'collectorAccount'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    fontFamily: 'Outfit',
                    color: DollDexTheme.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  t(context, 'signInBody'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: isDark ? Colors.white70 : DollDexTheme.cocoa,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                Theme(
                  data: Theme.of(context).copyWith(
                    unselectedWidgetColor:
                        isDark ? Colors.white30 : Colors.black38,
                  ),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _acceptedTermsAndPrivacy = !_acceptedTermsAndPrivacy;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: Checkbox(
                              value: _acceptedTermsAndPrivacy,
                              activeColor: DollDexTheme.teal,
                              checkColor: Colors.white,
                              onChanged: (val) {
                                setState(() {
                                  _acceptedTermsAndPrivacy = val ?? false;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Outfit',
                                  color:
                                      isDark ? Colors.white70 : Colors.black87,
                                ),
                                children: [
                                  TextSpan(
                                    text: tr
                                        ? 'Gizlilik Sözleşmesi'
                                        : 'Privacy Policy',
                                    style: const TextStyle(
                                      color: DollDexTheme.teal,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () => context.push('/privacy'),
                                  ),
                                  TextSpan(text: tr ? ' ve ' : ' and '),
                                  TextSpan(
                                    text: tr
                                        ? 'Kullanım Koşulları'
                                        : 'Terms of Use',
                                    style: const TextStyle(
                                      color: DollDexTheme.teal,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () => context.push('/terms'),
                                  ),
                                  TextSpan(
                                    text: tr
                                        ? '\'nı okudum ve kabul ediyorum.'
                                        : ' agreements, I read and accept.',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                PressableButton(
                  onTap: _canContinue ? widget.onGooglePressed : null,
                  scaleFactor: 0.96,
                  borderRadius: 24,
                  child: Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: _canContinue
                          ? const LinearGradient(
                              colors: [DollDexTheme.teal, Color(0xFFFF7A1F)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
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
                      boxShadow: _canContinue
                          ? [
                              BoxShadow(
                                color: DollDexTheme.teal.withValues(alpha: 0.38),
                                blurRadius: 18,
                                spreadRadius: -2,
                                offset: const Offset(0, 7),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: widget.isLoading
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.login_rounded,
                                    color: Colors.white, size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  t(context, 'continueGoogle'),
                                  style: TextStyle(
                                    color: _canContinue
                                        ? Colors.white
                                        : (isDark
                                            ? Colors.white30
                                            : Colors.black26),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    letterSpacing: 0.2,
                                    fontFamily: 'Outfit',
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
