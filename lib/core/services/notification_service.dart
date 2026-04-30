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

  /// Conversation id the user currently has open in the foreground, or
  /// null when no chat detail page is showing. Set from
  /// [ChatDetailPage.initState] / dispose. We use this client-side as a
  /// safety net: even if the server-side suppression isn't deployed yet
  /// (Render lagging behind code) we still skip the local banner for
  /// the chat the user is already looking at.
  String? _activeConversationId;
  void setActiveConversation(String? conversationId) {
    _activeConversationId = conversationId;
  }

  /// Conversation id the user tapped a notification for, but the app
  /// wasn't ready yet (still on splash, auth gate, etc.). The
  /// `MainNavPage` consumes this on each build and clears it after
  /// pushing the chat detail page. Without this, taps that fire before
  /// the navigator is mounted (cold-start tap) silently do nothing.
  String? pendingConversationTap;

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
        if (kDebugMode) {
          print('Local notification tapped: payload=${response.payload}');
        }
        // Foreground-banner taps (the local notification we show via
        // `_localNotifications.show` when an FCM arrives in foreground)
        // need the same deeplink wiring as background FCM taps. Reuse
        // pendingConversationTap so MainNavPage picks it up.
        final convoId = response.payload;
        if (convoId != null && convoId.isNotEmpty) {
          pendingConversationTap = convoId;
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
    final body = {'token': token, 'platform': platform};

    for (var attempt = 1; attempt <= 3; attempt++) {
      final response = await api.post('/devices/register', body: body);

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('Device registered with backend (platform: $platform, attempt: $attempt)');
        }
        return;
      }

      if (kDebugMode) {
        print('Device register attempt $attempt failed: ${response.statusCode}');
      }

      if (attempt < 3) {
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }

    if (kDebugMode) {
      print('Device register gave up after 3 attempts');
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

    // Suppress banners for the chat the user is currently looking at —
    // they already see the message live via WebSocket. Server-side
    // suppression covers the same case once Render is on the latest
    // build, but this guard removes the dependency on deploy timing.
    final pushedConvoId = (message.data['conversation_id'] as String?) ??
        (message.data['chatId'] as String?);
    if (pushedConvoId != null &&
        _activeConversationId != null &&
        pushedConvoId == _activeConversationId) {
      return;
    }

    // Show local notification for foreground messages
    final notification = message.notification;

    if (notification != null) {
      // Stable per-conversation id so multiple notifications for the
      // same chat collapse instead of stacking — and so we can cancel
      // them all when the user opens that chat. Falls back to a
      // pseudo-unique value when no conversation_id is present.
      final id = pushedConvoId != null
          ? pushedConvoId.hashCode
          : notification.hashCode;

      await _localNotifications.show(
        id,
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
        // Payload is the conversation id so the tap handler can deeplink.
        payload: pushedConvoId ?? message.data['chatId']?.toString() ?? '',
      );
    }
  }

  /// Clear all local-notification banners for a given conversation. Call
  /// this when the user opens the chat detail page so any pending push
  /// banners for that thread disappear from the lock screen / tray —
  /// matches WhatsApp / iMessage / Slack behavior.
  Future<void> clearNotificationsForConversation(String conversationId) async {
    try {
      await _localNotifications.cancel(conversationId.hashCode);
    } catch (e) {
      if (kDebugMode) {
        print('clearNotificationsForConversation failed: $e');
      }
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    if (kDebugMode) {
      print('Notification tapped: ${message.messageId} data=${message.data}');
    }
    // Server-side push payload includes both keys depending on origin:
    // chat backend uses `conversation_id`, older firestore code used
    // `chatId`. Accept either.
    final convoId = (message.data['conversation_id'] as String?) ??
        (message.data['chatId'] as String?);
    if (convoId == null || convoId.isEmpty) return;

    // Store for MainNavPage to pick up on its next build. Setting this
    // unconditionally is safe — if the user is already in a chat detail
    // page, MainNavPage will pop it before pushing the new one (handled
    // there).
    pendingConversationTap = convoId;
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

