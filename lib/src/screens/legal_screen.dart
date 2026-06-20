import 'package:flutter/material.dart';

import '../core/app_language.dart';
import '../widgets/doll_widgets.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({
    required this.title,
    required this.body,
    super.key,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: title,
      subtitle: t(context, 'legalSubtitle'),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(
            body,
            style: const TextStyle(
              fontFamily: 'Cinzel',
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ),
      ),
    );
  }
}
