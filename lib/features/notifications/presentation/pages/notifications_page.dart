import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart' as auth_providers;
import 'package:qent/features/notifications/domain/models/notification.dart';
import 'package:qent/features/notifications/presentation/controllers/notification_controller.dart';
import 'package:qent/features/notifications/presentation/providers/notification_providers.dart';
import 'package:qent/features/notifications/presentation/widgets/notification_skeleton.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  bool _showEmptyStateTimeout = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _showEmptyStateTimeout = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(auth_providers.firebaseAuthProvider).currentUser?.uid;
    final notificationsAsync = userId != null
        ? ref.watch(notificationsStreamProvider(userId))
        : const AsyncValue<List<NotificationModel>>.data([]);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: notificationsAsync.when(
          data: (notifications) {
            if (mounted && _showEmptyStateTimeout) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _showEmptyStateTimeout = false;
                  });
                }
              });
            }

            if (notifications.isEmpty) {
              return _buildEmptyState();
            }

            final todayNotifications = notifications.where((n) => n.isToday).toList();
            final previousNotifications = notifications.where((n) => !n.isToday).toList();
            final unreadCount = notifications.where((n) => !n.isRead).length;

            return Column(
              children: [
                _buildHeader(context, unreadCount),
                Expanded(
                  child: _buildNotificationList(
                    todayNotifications,
                    previousNotifications,
                  ),
                ),
              ],
            );
          },
          loading: () {
            if (_showEmptyStateTimeout) {
              return _buildEmptyState();
            }
            return Column(
              children: [
                _buildHeader(context, 0),
                Expanded(
                  child: SingleChildScrollView(
                    child: const NotificationListSkeleton(),
                  ),
                ),
              ],
            );
          },
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Error loading notifications',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    if (userId != null) {
                      ref.invalidate(notificationsStreamProvider(userId));
                    }
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int unreadCount) {
    final controller = ref.read(notificationControllerProvider.notifier);
    final state = ref.watch(notificationControllerProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 40),
          const Text(
            'Notification',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          GestureDetector(
            onTap: () {
              if (state.isSelectionMode) {
                _showDeleteConfirmation(context, controller);
              } else {
                controller.toggleSelectionMode();
              }
            },
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(
                state.isSelectionMode ? Icons.delete_outline : Icons.more_vert,
                color: Colors.black,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationList(
    List<NotificationModel> todayNotifications,
    List<NotificationModel> previousNotifications,
  ) {
    final controller = ref.read(notificationControllerProvider.notifier);
    final state = ref.watch(notificationControllerProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.isSelectionMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'All ${state.selectedIds.length} Selected',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      final allIds = [
                        ...todayNotifications.map((n) => n.id),
                        ...previousNotifications.map((n) => n.id),
                      ];
                      controller.selectAll(allIds);
                    },
                    child: const Text(
                      'Select All',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (todayNotifications.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Today',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    '${todayNotifications.where((n) => !n.isRead).length} Unread Notification${todayNotifications.where((n) => !n.isRead).length != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            ...todayNotifications.map((notification) =>
                _buildNotificationItem(notification, state.isSelectionMode, controller)),
          ],
          if (previousNotifications.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: const Text(
                'Previous',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            ...previousNotifications.map((notification) =>
                _buildNotificationItem(notification, state.isSelectionMode, controller)),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(
    NotificationModel notification,
    bool isSelectionMode,
    NotificationController controller,
  ) {
    final state = ref.watch(notificationControllerProvider);
    final isSelected = state.selectedIds.contains(notification.id);

    return GestureDetector(
      onTap: () {
        if (isSelectionMode) {
          controller.toggleSelection(notification.id);
        } else {
          controller.markAsRead(notification.id);
        }
      },
      onLongPress: () {
        if (!isSelectionMode) {
          controller.toggleSelectionMode();
          controller.toggleSelection(notification.id);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isSelectionMode)
              Padding(
                padding: const EdgeInsets.only(right: 12, top: 8),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.black : Colors.grey[400]!,
                      width: 2,
                    ),
                    color: isSelected ? Colors.black : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        )
                      : null,
                ),
              ),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: notification.iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                notification.icon,
                color: notification.iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  notification.timeAgo,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                if (!notification.isRead && !isSelectionMode) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, NotificationController controller) {
    final state = ref.watch(notificationControllerProvider);
    if (state.selectedIds.isEmpty) {
      controller.toggleSelectionMode();
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning,
                color: Colors.red,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Are you sure you want to delete your notifications permanently?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'By doing this, your notifications will be deleted permanently and you will not be able to recover your notifications anymore.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      controller.toggleSelectionMode();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      controller.deleteSelected();
                      controller.toggleSelectionMode();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Delete',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
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

  Widget _buildEmptyState() {
    return Column(
      children: [
        _buildHeader(context, 0),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications_off,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'NO NOTIFICATIONS',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Text(
                    'Clutter Cleared\n We will Notify You When There Is Something New.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

