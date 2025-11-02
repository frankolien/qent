import 'package:qent/features/notifications/data/datasources/firestore_notification_datasource.dart';
import 'package:qent/features/notifications/domain/models/notification.dart';
import 'package:qent/features/notifications/domain/repositories/notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final FirestoreNotificationDataSource _dataSource;

  NotificationRepositoryImpl(this._dataSource);

  @override
  Stream<List<NotificationModel>> getNotifications(String userId) {
    return _dataSource.getNotificationsStream(userId);
  }

  @override
  Future<void> markAsRead(String notificationId) {
    return _dataSource.markAsRead(notificationId);
  }

  @override
  Future<void> markMultipleAsRead(List<String> notificationIds) {
    return _dataSource.markMultipleAsRead(notificationIds);
  }

  @override
  Future<void> deleteNotification(String notificationId) {
    return _dataSource.deleteNotification(notificationId);
  }

  @override
  Future<void> deleteMultipleNotifications(List<String> notificationIds) {
    return _dataSource.deleteMultipleNotifications(notificationIds);
  }

  @override
  Future<void> createNotification(NotificationModel notification) {
    return _dataSource.createNotification(notification);
  }
}

