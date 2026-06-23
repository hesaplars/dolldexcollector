import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../main.dart';
import '../core/app_helpers.dart';
import '../core/app_language.dart';
import '../widgets/doll_widgets.dart';
import '../notifications/notification_models.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int _activeTab = 0; // 0: Bildirimler, 1: Duyurular

  Widget _buildNotificationsList(
    BuildContext context,
    List<AppNotification> list, {
    required bool canDelete,
    required String userId,
    required bool isTr,
  }) {
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0),
        child: Center(
          child: Text(
            isTr
                ? 'Bu kategoride bildirim bulunmuyor.'
                : 'No notifications in this category.',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final notification = list[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Dismissible(
            key: Key('notification-${notification.id}-${notification.isRead}'),
            direction: canDelete
                ? DismissDirection.horizontal
                : DismissDirection.startToEnd,
            background: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 16),
              child: Icon(Icons.mark_email_read_rounded,
                  color: Theme.of(context).colorScheme.primary, size: 18),
            ),
            secondaryBackground: canDelete
                ? Container(
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.error.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: Icon(Icons.delete_forever_rounded,
                        color: Theme.of(context).colorScheme.error, size: 18),
                  )
                : null,
            confirmDismiss: (direction) async {
              if (direction == DismissDirection.startToEnd) {
                await notificationRepository.markRead(notification.id);
                return false;
              } else if (direction == DismissDirection.endToStart &&
                  canDelete) {
                await notificationRepository.delete(notification.id);
                return true;
              }
              return false;
            },
            child: Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: notification.isRead
                      ? Colors.transparent
                      : Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(isDark ? 0.5 : 0.25),
                  width: 1,
                ),
              ),
              color: notification.isRead
                  ? Theme.of(context).colorScheme.surface
                  : Theme.of(context).colorScheme.primaryContainer,
              child: ListTile(
                dense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                onTap: () async {
                  final route = notification.deepLink;
                  if (!notification.isRead) {
                    notificationRepository.markRead(notification.id);
                  }
                  if (route.isNotEmpty && context.mounted) {
                    context.push(route);
                  }
                },
                leading: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: notification.isRead
                        ? Theme.of(context)
                            .colorScheme
                            .secondary
                            .withOpacity(0.1)
                        : Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.1),
                  ),
                  child: Icon(
                    notificationTypeIcon(notification.type),
                    color: notification.isRead
                        ? Theme.of(context).colorScheme.secondary
                        : Theme.of(context).colorScheme.primary,
                    size: 16,
                  ),
                ),
                title: Text(
                  notification.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: notification.isRead
                        ? FontWeight.normal
                        : FontWeight.bold,
                    color: notification.isRead
                        ? Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.7)
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    Text(
                      notification.body,
                      style: TextStyle(
                        fontSize: 11,
                        color: notification.isRead
                            ? Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.5)
                            : Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.8),
                      ),
                    ),
                    if (notification.createdAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        formatMessageTime(notification.createdAt!),
                        style: TextStyle(
                          fontSize: 9,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.4),
                        ),
                      ),
                    ],
                  ],
                ),
                trailing: notification.isRead
                    ? null
                    : Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = authService.currentUser;
    final userId = user?.uid ?? 'local-user';
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PageShell(
      title: tr ? 'Bildirimler' : 'Notifications',
      subtitle: tr
          ? 'Sosyal etkileşimler ve sistem duyuruları'
          : 'Social interactions and announcements',
      child: StreamBuilder<List<AppNotification>>(
        stream: notificationRepository.watchForUser(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary),
              ),
            );
          }

          final notifications = snapshot.data ?? [];
          final announcements = notifications
              .where((n) => n.deepLink.startsWith('/announcement'))
              .toList();
          final regularNotifications = notifications
              .where((n) => !n.deepLink.startsWith('/announcement'))
              .toList();

          if (notifications.isEmpty) {
            return EmptyState(
              icon: Icons.notifications_none_rounded,
              title: t(context, 'noNotifications'),
              body: t(context, 'noNotificationsBody'),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Action Row with mark all read button and info text
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: Theme.of(context).colorScheme.primary,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tr
                                  ? 'Sola kaydır: Sil | Sağa kaydır: Oku'
                                  : 'Swipe left: Delete | Swipe right: Read',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.7),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (userId != 'local-user') ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: Icon(Icons.done_all_rounded,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary),
                      label: Text(
                        tr ? 'Tümünü Oku' : 'Read All',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () async {
                        await notificationRepository.markAllRead(userId);
                      },
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              // Sekmeler
              Row(
                children: [
                  Expanded(
                    child: _buildTabButton(
                      label: tr
                          ? 'Bildirimler (${regularNotifications.length})'
                          : 'Notifications (${regularNotifications.length})',
                      isActive: _activeTab == 0,
                      onTap: () => setState(() => _activeTab = 0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTabButton(
                      label: tr
                          ? 'Duyurular (${announcements.length})'
                          : 'Announcements (${announcements.length})',
                      isActive: _activeTab == 1,
                      onTap: () => setState(() => _activeTab = 1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_activeTab == 0)
                _buildNotificationsList(
                  context,
                  regularNotifications,
                  canDelete: true,
                  userId: userId,
                  isTr: tr,
                )
              else
                _buildNotificationsList(
                  context,
                  announcements,
                  canDelete: false,
                  userId: userId,
                  isTr: tr,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isActive
              ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
              : Theme.of(context).colorScheme.surface,
          border: Border.all(
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ),
    );
  }
}
