import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'package:qent/core/services/api_client.dart';

/// Top-level function for handling background messages (must be top-level)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) {
    print('Handling background message: ${message.messageId}');
  }
}

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();
  
  bool _isInitialized = false;

  Future<void> initialize() async {
    // Skip if already initialized (hot restart scenario)
    if (_isInitialized) return;
    
    // Request permission
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) {
        print('User granted notification permission');
      }
    } else {
      if (kDebugMode) {
        print('User declined or has not accepted notification permission');
      }
    }

    // Initialize local notifications for foreground notifications
    await _initializeLocalNotifications();

    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Get initial message if app was opened from a notification
    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // Save FCM token to user document (non-blocking)
    _saveFCMToken().catchError((e) {
      if (kDebugMode) {
        print('Error saving FCM token: $e');
      }
    });
    
    _isInitialized = true;
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        if (kDebugMode) {
          print('Notification tapped: ${response.payload}');
        }
      },
    );

    // Create Android notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _saveFCMToken() async {
    final token = await _messaging.getToken();
    if (token != null) {
      await _registerWithBackend(token);
      await _saveTokenToFirestore(token);
    }

    _messaging.onTokenRefresh.listen((newToken) async {
      await _registerWithBackend(newToken);
      await _saveTokenToFirestore(newToken);
    });
  }

  Future<void> _registerWithBackend(String token) async {
    final api = ApiClient();
    if (!api.isAuthenticated) {
      if (kDebugMode) {
        print('Skipping backend device register — no auth token yet');
      }
      return;
    }

    final platform = Platform.isIOS ? 'ios' : (Platform.isAndroid ? 'android' : 'web');

    final response = await api.post(
      '/devices/register',
      body: {'token': token, 'platform': platform},
    );

    if (kDebugMode) {
      if (response.statusCode == 200) {
        print('Device registered with backend (platform: $platform)');
      } else {
        print('Device register failed: ${response.statusCode} ${response.body}');
      }
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final user = fb.FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        print('Firestore token save error (non-fatal): $e');
      }
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (kDebugMode) {
      print('Received foreground message: ${message.messageId}');
    }

    // Show local notification for foreground messages
    final notification = message.notification;

    if (notification != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title ?? 'New Message',
        notification.body ?? '',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription: 'This channel is used for important notifications.',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: message.data['chatId'] ?? '',
      );
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    if (kDebugMode) {
      print('Notification tapped: ${message.messageId}');
    }
    // Navigate to chat - this will be handled by the app's navigation logic
    // You can use a global navigator key or Riverpod state to navigate
  }

  Future<String?> getFCMToken() async {
    return await _messaging.getToken();
  }

  /// Call after a successful login/signup so the now-authenticated session can
  /// register its FCM token with the backend. Safe to call multiple times.
  Future<void> registerCurrentDeviceWithBackend() async {
    final token = await _messaging.getToken();
    if (token == null) return;
    await _registerWithBackend(token);
  }

  /// Call BEFORE clearing the auth token on logout so this device stops
  /// receiving pushes for the user that just signed out.
  Future<void> unregisterCurrentDeviceFromBackend() async {
    final api = ApiClient();
    if (!api.isAuthenticated) return;

    final token = await _messaging.getToken();
    if (token == null) return;

    final response = await api.delete('/devices/${Uri.encodeComponent(token)}');
    if (kDebugMode) {
      if (response.statusCode == 200) {
        print('Device unregistered from backend');
      } else {
        print('Device unregister failed: ${response.statusCode}');
      }
    }
  }
}

