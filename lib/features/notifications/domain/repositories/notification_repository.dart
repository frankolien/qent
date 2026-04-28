import 'package:qent/features/notifications/domain/models/notification.dart';

abstract class NotificationRepository {
  Future<List<NotificationModel>> getNotifications();
  Future<void> markAsRead(String notificationId);
  Future<void> markMultipleAsRead(List<String> notificationIds);
  Future<void> markAllAsRead();
  Future<void> deleteNotification(String notificationId);
  Future<void> deleteMultipleNotifications(List<String> notificationIds);
}
