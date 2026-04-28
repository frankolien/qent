import 'package:qent/features/notifications/data/datasources/api_notification_datasource.dart';
import 'package:qent/features/notifications/domain/models/notification.dart';
import 'package:qent/features/notifications/domain/repositories/notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final ApiNotificationDataSource _dataSource;

  NotificationRepositoryImpl(this._dataSource);

  @override
  Future<List<NotificationModel>> getNotifications() {
    return _dataSource.getNotifications();
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
  Future<void> markAllAsRead() {
    return _dataSource.markAllAsRead();
  }

  @override
  Future<void> deleteNotification(String notificationId) {
    return _dataSource.deleteNotification(notificationId);
  }

  @override
  Future<void> deleteMultipleNotifications(List<String> notificationIds) {
    return _dataSource.deleteMultiple(notificationIds);
  }
}
