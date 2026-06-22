import 'package:flutter/material.dart';
import '../catalog/catalog_models.dart';
import '../moderation/report_models.dart';
import '../widgets/doll_widgets.dart';
import 'app_language.dart';

import '../notifications/notification_models.dart';

String entryName(BuildContext context, CatalogEntry item) {
  return switch (item.id) {
    'template-character' => t(context, 'templateCharacterName'),
    'template-doll' => t(context, 'templateDollName'),
    'template-pet' => t(context, 'templatePetName'),
    'template-accessory' => t(context, 'templateAccessoryName'),
    _ => item.name,
  };
}

String entrySubtitle(BuildContext context, CatalogEntry item) {
  return switch (item.id) {
    'template-character' => t(context, 'templateCharacterSubtitle'),
    'template-doll' => t(context, 'templateDollSubtitle'),
    'template-pet' => t(context, 'templatePetSubtitle'),
    'template-accessory' => t(context, 'templateAccessorySubtitle'),
    _ => item.subtitle,
  };
}

String entryDescription(BuildContext context, CatalogEntry item) {
  return switch (item.id) {
    'template-character' => t(context, 'templateCharacterDescription'),
    'template-doll' => t(context, 'templateDollDescription'),
    'template-pet' => t(context, 'templatePetDescription'),
    'template-accessory' => t(context, 'templateAccessoryDescription'),
    _ => item.description,
  };
}

String catalogTypeLabel(BuildContext context, CatalogItemType type) {
  return switch (type) {
    CatalogItemType.character => t(context, 'typeCharacter'),
    CatalogItemType.doll => t(context, 'typeDoll'),
    CatalogItemType.set => t(context, 'typeSet'),
    CatalogItemType.pet => t(context, 'typePet'),
    CatalogItemType.accessory => t(context, 'typeAccessory'),
  };
}

String collectionStatusLabel(BuildContext context, CollectionStatus status) {
  return switch (status) {
    CollectionStatus.owned => t(context, 'statusOwned'),
    CollectionStatus.wanted => t(context, 'statusWanted'),
    CollectionStatus.trade => t(context, 'statusTrade'),
    CollectionStatus.selling => t(context, 'statusSelling'),
  };
}

String conditionLabel(BuildContext context, CollectionCondition condition) {
  final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
  return switch (condition) {
    CollectionCondition.boxed => tr ? 'Kutulu' : 'Boxed',
    CollectionCondition.unboxed => tr ? 'Kutusuz' : 'Unboxed',
    CollectionCondition.complete => tr ? 'Tam' : 'Complete',
    CollectionCondition.incomplete => tr ? 'Eksik' : 'Incomplete',
    CollectionCondition.damaged => tr ? 'Hasarlı' : 'Damaged',
  };
}

String reportReasonLabel(BuildContext context, ReportReason reason) {
  final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
  return switch (reason) {
    ReportReason.spam => 'Spam',
    ReportReason.harassment => tr ? 'Taciz' : 'Harassment',
    ReportReason.unsafeLink => tr ? 'Güvenli olmayan link' : 'Unsafe link',
    ReportReason.copyright => tr ? 'Telif hakkı' : 'Copyright',
    ReportReason.wrongInformation => tr ? 'Yanlış bilgi' : 'Wrong information',
    ReportReason.inappropriateImage =>
      tr ? 'Uygunsuz görsel' : 'Inappropriate image',
    ReportReason.other => tr ? 'Diğer' : 'Other',
  };
}

String reportStatusLabel(BuildContext context, ReportStatus status) {
  final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
  return switch (status) {
    ReportStatus.open => tr ? 'Açık' : 'Open',
    ReportStatus.reviewing => tr ? 'İncelemede' : 'Reviewing',
    ReportStatus.resolved => tr ? 'Çözüldü' : 'Resolved',
    ReportStatus.dismissed => tr ? 'Reddedildi' : 'Dismissed',
  };
}

String formatMessageTime(DateTime? value) {
  if (value == null) {
    return '';
  }

  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} ${two(local.hour)}:${two(local.minute)}';
}

Future<bool> showGothicConfirmDialog(
  BuildContext context, {
  required String title,
  required String content,
  String? confirmText,
  String? cancelText,
}) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
  final finalConfirmText = confirmText ?? (tr ? 'Onayla' : 'Confirm');
  final finalCancelText = cancelText ?? (tr ? 'Vazgeç' : 'Cancel');

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? DollDexTheme.darkPanel : DollDexTheme.panel,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                  color: isDark ? DollDexTheme.darkLine : DollDexTheme.line),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.28 : 0.14),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : DollDexTheme.ink,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  content,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : DollDexTheme.cocoa,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: isDark
                                  ? DollDexTheme.darkLine
                                  : DollDexTheme.line,
                              width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(
                          finalCancelText,
                          style: TextStyle(
                            color: isDark ? Colors.white : DollDexTheme.cocoa,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [DollDexTheme.teal, Color(0xFFFF7A1F)],
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text(
                            finalConfirmText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  return result ?? false;
}

IconData notificationTypeIcon(AppNotificationType type) {
  return switch (type) {
    AppNotificationType.comment => Icons.comment_outlined,
    AppNotificationType.like => Icons.favorite_border_rounded,
    AppNotificationType.follow => Icons.person_add_outlined,
    AppNotificationType.friendRequest => Icons.people_outline_rounded,
    AppNotificationType.message => Icons.mail_outline_rounded,
    AppNotificationType.moderation => Icons.gavel_rounded,
    AppNotificationType.pro => Icons.workspace_premium_outlined,
  };
}
