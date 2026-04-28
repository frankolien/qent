import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/features/notifications/data/datasources/api_notification_datasource.dart';
import 'package:qent/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:qent/features/notifications/domain/models/notification.dart';
import 'package:qent/features/notifications/domain/repositories/notification_repository.dart';
import 'package:qent/features/notifications/presentation/controllers/notification_controller.dart';

final notificationDataSourceProvider = Provider<ApiNotificationDataSource>((ref) {
  return ApiNotificationDataSource();
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final dataSource = ref.watch(notificationDataSourceProvider);
  return NotificationRepositoryImpl(dataSource);
});

final notificationControllerProvider =
    NotifierProvider<NotificationController, NotificationState>(() {
  return NotificationController();
});

/// Fetches the current user's notifications from the backend. Refresh by
/// invalidating this provider (`ref.invalidate(notificationsProvider)`).
final notificationsProvider = FutureProvider<List<NotificationModel>>((ref) async {
  final repository = ref.watch(notificationRepositoryProvider);
  return repository.getNotifications();
});
