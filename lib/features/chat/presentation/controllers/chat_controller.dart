import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/features/chat/data/datasources/firestore_chat_datasource.dart';
import 'package:qent/features/chat/data/datasources/fcm_notification_datasource.dart';
import 'package:qent/features/chat/domain/models/chat.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_messaging/firebase_messaging.dart';

// Reuse existing providers
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
final firebaseAuthProvider = Provider<fb.FirebaseAuth>((ref) => fb.FirebaseAuth.instance);
final firebaseMessagingProvider = Provider<FirebaseMessaging>((ref) => FirebaseMessaging.instance);

final fcmNotificationDataSourceProvider = Provider<FCMNotificationDataSource>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final messaging = ref.watch(firebaseMessagingProvider);
  return FCMNotificationDataSource(firestore: firestore, messaging: messaging);
});

final firestoreChatDataSourceProvider = Provider<FirestoreChatDataSource>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final auth = ref.watch(firebaseAuthProvider);
  final notificationDataSource = ref.watch(fcmNotificationDataSourceProvider);
  return FirestoreChatDataSource(
    firestore: firestore,
    auth: auth,
    notificationDataSource: notificationDataSource,
  );
});

// Stream provider for user search
final usersSearchStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, query) {
  final dataSource = ref.watch(firestoreChatDataSourceProvider);
  if (query.isEmpty) {
    return dataSource.getAllUsers();
  }
  return dataSource.searchUsers(query);
});

// Stream provider for chats
final chatsStreamProvider = StreamProvider<List<Chat>>((ref) {
  final dataSource = ref.watch(firestoreChatDataSourceProvider);
  return dataSource.getChatsStream();
});

// Stream provider for messages in a specific chat
final messagesStreamProvider = StreamProvider.family<List<ChatMessage>, String>((ref, chatId) {
  final dataSource = ref.watch(firestoreChatDataSourceProvider);
  return dataSource.getMessagesStream(chatId);
});

// Chat controller
class ChatController {
  final FirestoreChatDataSource _dataSource;

  ChatController(this._dataSource);

  Future<void> sendMessage({
    required String chatId,
    required String message,
    MessageType type = MessageType.text,
  }) async {
    try {
      await _dataSource.sendMessage(
        chatId: chatId,
        message: message,
        type: type,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> markAsRead(String chatId) async {
    try {
      await _dataSource.markMessagesAsRead(chatId);
    } catch (e) {
      // Handle error silently
    }
  }

  Future<String> createOrGetChat(String otherUserId) async {
    try {
      return await _dataSource.createOrGetChat(otherUserId);
    } catch (e) {
      rethrow;
    }
  }
}

final chatControllerProvider = Provider<ChatController>((ref) {
  final dataSource = ref.watch(firestoreChatDataSourceProvider);
  return ChatController(dataSource);
});
