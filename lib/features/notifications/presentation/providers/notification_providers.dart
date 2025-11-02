import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart' as auth_providers;
import 'package:qent/features/notifications/data/datasources/firestore_notification_datasource.dart';
import 'package:qent/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:qent/features/notifications/domain/models/notification.dart';
import 'package:qent/features/notifications/domain/repositories/notification_repository.dart';
import 'package:qent/features/notifications/presentation/controllers/notification_controller.dart';

final notificationDataSourceProvider = Provider<FirestoreNotificationDataSource>((ref) {
  return FirestoreNotificationDataSource();
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final dataSource = ref.watch(notificationDataSourceProvider);
  return NotificationRepositoryImpl(dataSource);
});

final notificationControllerProvider =
    NotifierProvider<NotificationController, NotificationState>(() {
  return NotificationController();
});

final notificationsStreamProvider = StreamProvider.family<List<NotificationModel>, String>((ref, userId) {
  final repository = ref.watch(notificationRepositoryProvider);
  return repository.getNotifications(userId);
});

final currentUserNotificationsProvider = StreamProvider<List<NotificationModel>>((ref) {
  final userId = ref.watch(auth_providers.firebaseAuthProvider).currentUser?.uid;
  if (userId == null) {
    return Stream.value([]);
  }
  final repository = ref.watch(notificationRepositoryProvider);
  return repository.getNotifications(userId);
});

