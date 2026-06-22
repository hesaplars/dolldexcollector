import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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
        constraints: const BoxConstraints(maxWidth: 310),
        child: Card(
          elevation: 4,
          color: isDark ? const Color(0xFF130B1E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: const Color(0xFFEC008C).withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFEC008C),
                          width: 1.2,
                        ),
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
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t(context, 'collectorAccount'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              fontFamily: 'Outfit',
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            t(context, 'signInBody'),
                            style: TextStyle(
                              fontSize: 9.5,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const SizedBox(height: 10),
                Theme(
                  data: Theme.of(context).copyWith(
                    unselectedWidgetColor: isDark ? Colors.white30 : Colors.black38,
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
                              activeColor: const Color(0xFFEC008C),
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
                                  fontSize: 10,
                                  fontFamily: 'Outfit',
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                                children: [
                                  TextSpan(
                                    text: tr ? 'Gizlilik Sözleşmesi' : 'Privacy Policy',
                                    style: const TextStyle(
                                      color: Color(0xFF00FFCC),
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () => context.push('/privacy'),
                                  ),
                                  TextSpan(text: tr ? ' ve ' : ' and '),
                                  TextSpan(
                                    text: tr ? 'Kullanım Koşulları' : 'Terms of Use',
                                    style: const TextStyle(
                                      color: Color(0xFF00FFCC),
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
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: _canContinue
                        ? const LinearGradient(
                            colors: [Color(0xFFEC008C), Color(0xFF7B2CBF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : LinearGradient(
                            colors: [
                              isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                              isDark ? Colors.grey.shade900 : Colors.grey.shade400
                            ],
                          ),
                    boxShadow: _canContinue
                        ? [
                            BoxShadow(
                              color: const Color(0xFFEC008C).withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _canContinue ? widget.onGooglePressed : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    icon: widget.isLoading
                        ? const SizedBox.square(
                            dimension: 12,
                            child: CircularProgressIndicator(strokeWidth: 1.2, color: Colors.white),
                          )
                        : const Icon(Icons.login_rounded, color: Colors.white, size: 14),
                    label: Text(
                      t(context, 'continueGoogle'),
                      style: TextStyle(
                        color: _canContinue ? Colors.white : (isDark ? Colors.white30 : Colors.black26),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 0.5,
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
    );
  }
}
