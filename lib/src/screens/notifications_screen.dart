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
            isTr ? 'Bu kategoride bildirim bulunmuyor.' : 'No notifications in this category.',
            style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.white54),
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
            direction: canDelete ? DismissDirection.horizontal : DismissDirection.startToEnd,
            background: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF00FFCC).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 16),
              child: const Icon(Icons.mark_email_read_rounded, color: Color(0xFF00FFCC), size: 18),
            ),
            secondaryBackground: canDelete
                ? Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFEC008C).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete_forever_rounded, color: Color(0xFFEC008C), size: 18),
                  )
                : null,
            confirmDismiss: (direction) async {
              if (direction == DismissDirection.startToEnd) {
                await notificationRepository.markRead(notification.id);
                return false;
              } else if (direction == DismissDirection.endToStart && canDelete) {
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
                      : (isDark
                          ? const Color(0xFFEC008C).withOpacity(0.5)
                          : const Color(0xFFEC008C).withOpacity(0.25)),
                  width: 1,
                ),
              ),
              color: isDark
                  ? (notification.isRead ? const Color(0xFF0F0918) : const Color(0xFF170D26))
                  : (notification.isRead ? const Color(0xFFF9F6FC) : const Color(0xFFF0E6F5)),
              child: ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
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
                      ? Colors.grey.withOpacity(0.1)
                      : const Color(0xFFEC008C).withOpacity(0.1),
                  ),
                  child: Icon(
                    notificationTypeIcon(notification.type),
                    color: notification.isRead ? Colors.grey : const Color(0xFFEC008C),
                    size: 16,
                  ),
                ),
                title: Text(
                  notification.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                    color: isDark
                        ? (notification.isRead ? const Color(0xFFB5A7C5) : Colors.white)
                        : (notification.isRead ? const Color(0xFF6B5885) : Colors.black87),
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
                        color: isDark
                            ? (notification.isRead ? const Color(0xFF8E7E9D) : const Color(0xFFC4B2D9))
                            : (notification.isRead ? const Color(0xFF8E7E9D) : const Color(0xFF6B5885)),
                      ),
                    ),
                    if (notification.createdAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        formatMessageTime(notification.createdAt!),
                        style: TextStyle(
                          fontSize: 9,
                          color: isDark ? Colors.white38 : Colors.black38,
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
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF00FFCC),
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
      subtitle: tr ? 'Sosyal etkileşimler ve sistem duyuruları' : 'Social interactions and announcements',
      child: StreamBuilder<List<AppNotification>>(
        stream: notificationRepository.watchForUser(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEC008C)),
              ),
            );
          }

          final notifications = snapshot.data ?? [];
          final announcements = notifications.where((n) => n.deepLink.startsWith('/announcement')).toList();
          final regularNotifications = notifications.where((n) => !n.deepLink.startsWith('/announcement')).toList();

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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF160E24) : const Color(0xFFFAF6FC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF00FFCC).withOpacity(0.2)
                              : const Color(0xFFEC008C).withOpacity(0.15),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: isDark ? const Color(0xFF00FFCC) : const Color(0xFFEC008C),
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
                                color: isDark ? const Color(0xFFE5DDF2) : const Color(0xFF6B5885),
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
                      icon: const Icon(Icons.done_all_rounded, size: 16, color: Color(0xFF00FFCC)),
                      label: Text(
                        tr ? 'Tümünü Oku' : 'Read All',
                        style: const TextStyle(
                          color: Color(0xFF00FFCC),
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
                      label: tr ? 'Bildirimler (${regularNotifications.length})' : 'Notifications (${regularNotifications.length})',
                      isActive: _activeTab == 0,
                      onTap: () => setState(() => _activeTab = 0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTabButton(
                      label: tr ? 'Duyurular (${announcements.length})' : 'Announcements (${announcements.length})',
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
              ? const Color(0xFFEC008C).withOpacity(0.15)
              : (isDark ? const Color(0xFF160E22) : Colors.white),
          border: Border.all(
            color: isActive
                ? const Color(0xFFEC008C)
                : (isDark ? const Color(0xFF2C1F45) : const Color(0xFFEC008C).withOpacity(0.2)),
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive
                ? (isDark ? Colors.white : const Color(0xFFEC008C))
                : (isDark ? Colors.white70 : const Color(0xFF6B5885)),
          ),
        ),
      ),
    );
  }
}
