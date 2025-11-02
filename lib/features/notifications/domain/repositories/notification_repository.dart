import 'package:qent/features/notifications/domain/models/notification.dart';

abstract class NotificationRepository {
  Stream<List<NotificationModel>> getNotifications(String userId);
  Future<void> markAsRead(String notificationId);
  Future<void> markMultipleAsRead(List<String> notificationIds);
  Future<void> deleteNotification(String notificationId);
  Future<void> deleteMultipleNotifications(List<String> notificationIds);
  Future<void> createNotification(NotificationModel notification);
}

