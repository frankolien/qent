import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/core/services/api_client.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart';
import 'package:qent/features/chat/data/datasources/api_chat_datasource.dart';
import 'package:qent/features/chat/domain/models/chat.dart';

// API chat datasource provider
final apiChatDataSourceProvider = Provider<ApiChatDataSource>((ref) {
  final authState = ref.watch(authControllerProvider);
  final userId = authState.user?.uid ?? '';
  return ApiChatDataSource(apiClient: ApiClient(), currentUserId: userId);
});

// FutureProvider for conversations list
final chatsProvider = FutureProvider<List<Chat>>((ref) async {
  final dataSource = ref.watch(apiChatDataSourceProvider);
  return dataSource.getConversations();
});

// For backward compat with the UI that uses chatsStreamProvider
final chatsStreamProvider = StreamProvider<List<Chat>>((ref) async* {
  final dataSource = ref.watch(apiChatDataSourceProvider);
  try {
    final chats = await dataSource.getConversations();
    yield chats;
  } catch (e) {
    debugPrint('[Qent Chat] Error loading conversations: $e');
    yield [];
  }
});

// FutureProvider for messages in a specific conversation
final messagesProvider = FutureProvider.family<List<ChatMessage>, String>((ref, conversationId) async {
  final dataSource = ref.watch(apiChatDataSourceProvider);
  return dataSource.getMessages(conversationId);
});

// For backward compat with the UI that uses messagesStreamProvider
final messagesStreamProvider = StreamProvider.family<List<ChatMessage>, String>((ref, conversationId) async* {
  final dataSource = ref.watch(apiChatDataSourceProvider);
  try {
    final messages = await dataSource.getMessages(conversationId);
    yield messages;
  } catch (e) {
    debugPrint('[Qent Chat] Error loading messages: $e');
    yield [];
  }
});

// Chat controller for actions
class ChatController {
  final ApiChatDataSource _dataSource;
  final Ref _ref;

  ChatController(this._dataSource, this._ref);

  Future<Chat> getOrCreateConversation(String carId, String hostId) async {
    return await _dataSource.getOrCreateConversation(carId, hostId);
  }

  Future<void> sendMessage({
    required String chatId,
    required String message,
    MessageType type = MessageType.text,
    String? replyToMessageId,
    ReplyInfo? replyTo,
  }) async {
    await _dataSource.sendMessage(
      chatId,
      message,
      type: type,
      replyToId: replyToMessageId,
    );
    // Refresh messages and conversation list after sending
    _ref.invalidate(messagesStreamProvider(chatId));
    _ref.invalidate(messagesProvider(chatId));
    _ref.invalidate(chatsStreamProvider);
    _ref.invalidate(chatsProvider);
  }

  Future<void> markAsRead(String chatId) async {
    try {
      await _dataSource.markAsRead(chatId);
    } catch (e) {
      debugPrint('[Qent Chat] Error marking as read: $e');
    }
  }

  Future<void> deleteConversation(String chatId) async {
    await _dataSource.deleteConversation(chatId);
    _ref.invalidate(chatsStreamProvider);
    _ref.invalidate(chatsProvider);
  }

  // Typing status - no-op for now (would need WebSocket)
  Future<void> setTypingStatus(String chatId, bool isTyping) async {}

  // Delete message - not implemented yet
  Future<void> deleteMessage(String chatId, String messageId) async {}

  // Forward message - not implemented yet
  Future<void> forwardMessage({
    required String fromChatId,
    required String toChatId,
    required ChatMessage message,
  }) async {}
}

final chatControllerProvider = Provider<ChatController>((ref) {
  final dataSource = ref.watch(apiChatDataSourceProvider);
  return ChatController(dataSource, ref);
});
