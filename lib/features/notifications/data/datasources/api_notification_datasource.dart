import 'package:qent/core/services/api_client.dart';
import 'package:qent/features/notifications/domain/models/notification.dart';

/// Backend-API datasource. Replaces the Firestore datasource for everything
/// except live realtime updates (which the API doesn't push — callers refresh
/// manually or on relevant events).
class ApiNotificationDataSource {
  final ApiClient _api;

  ApiNotificationDataSource({ApiClient? api}) : _api = api ?? ApiClient();

  Future<List<NotificationModel>> getNotifications() async {
    final res = await _api.get('/notifications');
    if (!res.isSuccess) {
      throw Exception(res.errorMessage);
    }
    final body = res.body;
    if (body is! List) return [];
    return body
        .whereType<Map<String, dynamic>>()
        .map(NotificationModel.fromBackendJson)
        .toList();
  }

  Future<void> markAsRead(String notificationId) async {
    final res = await _api.post('/notifications/$notificationId/read');
    if (!res.isSuccess) throw Exception(res.errorMessage);
  }

  Future<void> markAllAsRead() async {
    final res = await _api.post('/notifications/read-all');
    if (!res.isSuccess) throw Exception(res.errorMessage);
  }

  Future<void> markMultipleAsRead(List<String> ids) async {
    // Backend has no bulk mark-read endpoint; fan out individual calls.
    await Future.wait(ids.map(markAsRead));
  }

  Future<void> deleteNotification(String notificationId) async {
    final res = await _api.delete('/notifications/$notificationId');
    if (!res.isSuccess) throw Exception(res.errorMessage);
  }

  Future<void> deleteMultiple(List<String> ids) async {
    if (ids.isEmpty) return;
    final res = await _api.post(
      '/notifications/delete-bulk',
      body: {'ids': ids},
    );
    if (!res.isSuccess) throw Exception(res.errorMessage);
  }
}
