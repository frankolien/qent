import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qent/features/notifications/domain/models/notification.dart';

class FirestoreNotificationDataSource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<NotificationModel>> getNotificationsStream(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return _notificationFromFirestore(doc);
      }).toList();
    });
  }

  Future<void> markAsRead(String notificationId) async {
    await _firestore
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  Future<void> markMultipleAsRead(List<String> notificationIds) async {
    final batch = _firestore.batch();
    for (final id in notificationIds) {
      final ref = _firestore.collection('notifications').doc(id);
      batch.update(ref, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> deleteNotification(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).delete();
  }

  Future<void> deleteMultipleNotifications(List<String> notificationIds) async {
    final batch = _firestore.batch();
    for (final id in notificationIds) {
      final ref = _firestore.collection('notifications').doc(id);
      batch.delete(ref);
    }
    await batch.commit();
  }

  Future<void> createNotification(NotificationModel notification) async {
    await _firestore
        .collection('notifications')
        .doc(notification.id)
        .set(_notificationToFirestore(notification));
  }

  NotificationModel _notificationFromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: _stringToNotificationType(data['type'] ?? 'bookingSuccess'),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
      imageUrl: data['imageUrl'],
      data: data['data'],
    );
  }

  Map<String, dynamic> _notificationToFirestore(NotificationModel notification) {
    return {
      'userId': notification.userId,
      'title': notification.title,
      'message': notification.message,
      'type': _notificationTypeToString(notification.type),
      'timestamp': Timestamp.fromDate(notification.timestamp),
      'isRead': notification.isRead,
      'imageUrl': notification.imageUrl,
      'data': notification.data,
    };
  }

  String _notificationTypeToString(NotificationType type) {
    switch (type) {
      case NotificationType.bookingSuccess:
        return 'bookingSuccess';
      case NotificationType.payment:
        return 'payment';
      case NotificationType.pickupDropoff:
        return 'pickupDropoff';
      case NotificationType.lateReturn:
        return 'lateReturn';
      case NotificationType.cancellation:
        return 'cancellation';
      case NotificationType.discount:
        return 'discount';
    }
  }

  NotificationType _stringToNotificationType(String type) {
    switch (type) {
      case 'bookingSuccess':
        return NotificationType.bookingSuccess;
      case 'payment':
        return NotificationType.payment;
      case 'pickupDropoff':
        return NotificationType.pickupDropoff;
      case 'lateReturn':
        return NotificationType.lateReturn;
      case 'cancellation':
        return NotificationType.cancellation;
      case 'discount':
        return NotificationType.discount;
      default:
        return NotificationType.bookingSuccess;
    }
  }
}

