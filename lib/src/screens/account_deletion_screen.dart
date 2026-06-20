import 'package:flutter/material.dart';
import 'package:dolldex_collector/main.dart';
import 'package:dolldex_collector/src/core/app_language.dart';
import 'package:dolldex_collector/src/widgets/doll_widgets.dart';

class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({super.key});

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: t(context, 'deleteAccount'),
      subtitle: t(context, 'legalSubtitle'),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t(context, 'deleteBody')),
              const SizedBox(height: 16),
              TextField(
                controller: _reasonController,
                minLines: 3,
                maxLines: 5,
                style: const TextStyle(fontFamily: 'Outfit'),
                decoration: InputDecoration(
                  labelText: t(context, 'deleteReason'),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text(t(context, 'sendDeleteRequest')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final user = authService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(context, 'signInNeedsFirebase'))),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await accountDeletionRepository.requestDeletion(
        userId: user.uid,
        email: user.email ?? '',
        reason: _reasonController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      _reasonController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(context, 'deleteRequestSaved'))),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t(context, 'deleteRequestFailed')} $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
