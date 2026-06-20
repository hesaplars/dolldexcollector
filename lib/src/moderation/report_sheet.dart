import 'package:flutter/material.dart';

import '../core/app_language.dart';
import 'report_models.dart';

class ReportSheet extends StatefulWidget {
  const ReportSheet({
    required this.targetType,
    required this.targetId,
    required this.onSubmit,
    super.key,
  });

  final ReportTargetType targetType;
  final String targetId;
  final ValueChanged<ReportDraft> onSubmit;

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  final _detailsController = TextEditingController();
  ReportReason _reason = ReportReason.spam;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t(context, 'report'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ReportReason>(
              initialValue: _reason,
              decoration: InputDecoration(
                labelText: AppLanguageScope.languageOf(context) == AppLanguage.tr
                    ? 'Sebep'
                    : 'Reason',
                prefixIcon: const Icon(Icons.flag_outlined),
              ),
              items: ReportReason.values
                  .map(
                    (reason) => DropdownMenuItem(
                      value: reason,
                      child: Text(_reasonLabel(context, reason)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _reason = value);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _detailsController,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: AppLanguageScope.languageOf(context) == AppLanguage.tr
                    ? 'Detaylar'
                    : 'Details',
                alignLabelWithHint: true,
                prefixIcon: const Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      AppLanguageScope.languageOf(context) == AppLanguage.tr
                      ? 'Vazgeç'
                          : 'Cancel',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      widget.onSubmit(
                        ReportDraft(
                          targetType: widget.targetType,
                          targetId: widget.targetId,
                          reason: _reason,
                          details: _detailsController.text.trim(),
                        ),
                      );
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.send_outlined),
                    label: Text(
                      AppLanguageScope.languageOf(context) == AppLanguage.tr
                          ? 'Gönder'
                          : 'Send',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ReportDraft {
  const ReportDraft({
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.details,
  });

  final ReportTargetType targetType;
  final String targetId;
  final ReportReason reason;
  final String details;
}

String _reasonLabel(BuildContext context, ReportReason reason) {
  final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
  return switch (reason) {
    ReportReason.spam => 'Spam',
    ReportReason.harassment => tr ? 'Taciz' : 'Harassment',
    ReportReason.unsafeLink => tr ? 'Güvenli olmayan link' : 'Unsafe link',
    ReportReason.copyright => tr ? 'Telif hakkı' : 'Copyright',
    ReportReason.wrongInformation => tr ? 'Yanlış bilgi' : 'Wrong information',
    ReportReason.inappropriateImage =>
      tr ? 'Uygunsuz gorsel' : 'Inappropriate image',
    ReportReason.other => tr ? 'Diğer' : 'Other',
  };
}
