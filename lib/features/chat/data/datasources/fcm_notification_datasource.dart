import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FCMNotificationDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;

  // You need to get this from Firebase Console > Project Settings > Cloud Messaging > Server key
  // For production, store this securely on your backend server or use Cloud Functions
  static const String _serverKey = 'YOUR_SERVER_KEY_HERE'; // TODO: Replace with actual server key from Firebase Console
  static const String _fcmEndpoint = 'https://fcm.googleapis.com/fcm/send';

  FCMNotificationDataSource({
    required FirebaseFirestore firestore,
    required FirebaseMessaging messaging,
  })  : _firestore = firestore,
        _messaging = messaging;

  // Get the FCM token - can be used for testing
  Future<String?> getToken() async {
    return await _messaging.getToken();
  }

  // Get FCM token for a user
  Future<String?> getFCMToken(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return null;
      return userDoc.data()?['fcmToken'] as String?;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting FCM token: $e');
      }
      return null;
    }
  }

  // Send notification via FCM REST API
  Future<void> sendNotification({
    required String fcmToken,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      // Skip if server key is not configured
      if (_serverKey == 'YOUR_SERVER_KEY_HERE') {
        debugPrint('FCM Server key not configured. Please set it in fcm_notification_datasource.dart');
        return;
      }

      final response = await http.post(
        Uri.parse(_fcmEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$_serverKey',
        },
        body: jsonEncode({
          'to': fcmToken,
          'notification': {
            'title': title,
            'body': body,
            'sound': 'default',
          },
          'data': data,
          'priority': 'high',
        }),
      );

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('Notification sent successfully');
        }
      } else {
        if (kDebugMode) {
          print('Failed to send notification: ${response.statusCode} - ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending notification: $e');
      }
    }
  }

  // Send notification to user by userId
  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    final fcmToken = await getFCMToken(userId);
    if (fcmToken != null) {
      await sendNotification(
        fcmToken: fcmToken,
        title: title,
        body: body,
        data: data,
      );
    }
  }
}

