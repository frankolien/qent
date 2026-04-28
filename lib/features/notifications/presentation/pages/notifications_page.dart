import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/core/theme/app_theme.dart';
import 'package:qent/features/notifications/domain/models/notification.dart';
import 'package:qent/features/notifications/presentation/providers/notification_providers.dart';
import 'package:qent/features/notifications/presentation/widgets/notification_skeleton.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: context.bgPrimary,
      body: SafeArea(
        child: notificationsAsync.when(
          data: (notifications) => _Loaded(notifications: notifications),
          loading: () => Column(
            children: [
              const _Header(unreadCount: 0),
              Expanded(
                child: SingleChildScrollView(
                  child: const NotificationListSkeleton(),
                ),
              ),
            ],
          ),
          error: (err, _) => _ErrorState(error: err.toString()),
        ),
      ),
    );
  }
}

class _Loaded extends ConsumerWidget {
  final List<NotificationModel> notifications;
  const _Loaded({required this.notifications});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = notifications.where((n) => n.isToday).toList();
    final previous = notifications.where((n) => !n.isToday).toList();
    final unread = notifications.where((n) => !n.isRead).length;

    return Column(
      children: [
        _Header(unreadCount: unread),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(notificationsProvider),
            child: notifications.isEmpty
                ? const _EmptyState()
                : _NotificationList(today: today, previous: previous),
          ),
        ),
      ],
    );
  }
}

class _Header extends ConsumerWidget {
  final int unreadCount;
  const _Header({required this.unreadCount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(notificationControllerProvider.notifier);
    final state = ref.watch(notificationControllerProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: context.textPrimary, size: 20),
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: Center(
              child: Text(
                'Notification',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
            ),
          ),
          if (state.isSelectionMode)
            IconButton(
              onPressed: () => _showDeleteConfirmation(context, ref),
              icon: const Icon(Icons.delete_outline, size: 22),
              color: context.textPrimary,
              visualDensity: VisualDensity.compact,
            )
          else
            PopupMenuButton<String>(
              icon: Icon(Icons.more_horiz, color: context.textPrimary, size: 22),
              onSelected: (value) {
                switch (value) {
                  case 'select':
                    controller.toggleSelectionMode();
                    break;
                  case 'mark_all':
                    controller.markAllAsRead();
                    break;
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'select', child: Text('Select')),
                PopupMenuItem(value: 'mark_all', child: Text('Mark all as read')),
              ],
            ),
        ],
      ),
    );
  }
}

class _NotificationList extends ConsumerWidget {
  final List<NotificationModel> today;
  final List<NotificationModel> previous;
  const _NotificationList({required this.today, required this.previous});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(notificationControllerProvider.notifier);
    final state = ref.watch(notificationControllerProvider);
    final unreadToday = today.where((n) => !n.isRead).length;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        if (state.isSelectionMode)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    final allIds = [
                      ...today.map((n) => n.id),
                      ...previous.map((n) => n.id),
                    ];
                    final allSelected = state.selectedIds.length == allIds.length;
                    if (allSelected) {
                      controller.clearSelection();
                    } else {
                      controller.selectAll(allIds);
                    }
                  },
                  child: _Checkbox(
                    checked: state.selectedIds.length ==
                        (today.length + previous.length),
                  ),
                ),
                const SizedBox(width: 8),
                Text('All',
                    style: TextStyle(
                        fontSize: 14,
                        color: context.textPrimary,
                        fontWeight: FontWeight.w500)),
                const Spacer(),
                Text('${state.selectedIds.length} Selected',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey[600])),
              ],
            ),
          ),
        if (today.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Today',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary)),
                if (!state.isSelectionMode && unreadToday > 0)
                  Text('$unreadToday Unread Notification',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          ...today.map((n) => _NotificationTile(notification: n)),
        ],
        if (previous.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Previous',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary)),
          ),
          ...previous.map((n) => _NotificationTile(notification: n)),
        ],
      ],
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  final NotificationModel notification;
  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(notificationControllerProvider.notifier);
    final state = ref.watch(notificationControllerProvider);
    final isSelected = state.selectedIds.contains(notification.id);

    return InkWell(
      onTap: () {
        if (state.isSelectionMode) {
          controller.toggleSelection(notification.id);
        } else if (!notification.isRead) {
          controller.markAsRead(notification.id);
        }
      },
      onLongPress: () {
        if (!state.isSelectionMode) {
          controller.toggleSelectionMode();
          controller.toggleSelection(notification.id);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.isSelectionMode) ...[
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _Checkbox(checked: isSelected),
              ),
              const SizedBox(width: 12),
            ],
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : const Color(0xFFF2F2F2),
                shape: BoxShape.circle,
              ),
              child: Icon(notification.icon,
                  color: context.textPrimary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notification.title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: notification.isRead
                              ? FontWeight.w600
                              : FontWeight.w700,
                          color: context.textPrimary)),
                  const SizedBox(height: 4),
                  Text(notification.message,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(notification.timeAgo,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                if (!notification.isRead && !state.isSelectionMode) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: Colors.blue, shape: BoxShape.circle),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Checkbox extends StatelessWidget {
  final bool checked;
  const _Checkbox({required this.checked});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
            color: checked ? Colors.black : Colors.grey[400]!, width: 2),
        color: checked ? Colors.black : Colors.transparent,
      ),
      child: checked
          ? const Icon(Icons.check, color: Colors.white, size: 14)
          : null,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
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
                  child: Icon(Icons.notifications_off,
                      size: 56, color: Colors.grey[400]),
                ),
                const SizedBox(height: 24),
                Text('NO NOTIFICATIONS',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary)),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Text(
                    'Clutter Cleared.\nWe will notify you when there is something new.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey[600], height: 1.4),
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

class _ErrorState extends ConsumerWidget {
  final String error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.grey[500], size: 48),
            const SizedBox(height: 12),
            Text('Could not load notifications',
                style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(error,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(notificationsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
  final controller = ref.read(notificationControllerProvider.notifier);
  final state = ref.read(notificationControllerProvider);
  if (state.selectedIds.isEmpty) {
    controller.toggleSelectionMode();
    return;
  }

  showDialog(
    context: context,
    builder: (dialogContext) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: Colors.red, size: 32),
            ),
            const SizedBox(height: 20),
            const Text(
              'Are you sure you want to delete your notifications permanently?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              'By doing this, your notifications will be deleted permanently and you will not be able to recover your notifications anymore.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12, color: Colors.grey[600], height: 1.4),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      Navigator.pop(dialogContext);
                      await controller.deleteSelected();
                      controller.toggleSelectionMode();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Delete',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
