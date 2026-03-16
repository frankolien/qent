import 'package:flutter/foundation.dart';
import 'package:qent/core/services/api_client.dart';
import 'package:qent/features/chat/domain/models/chat.dart';

/// Chat datasource backed by the Qent Rust API.
/// Replaces Firestore-based chat with REST endpoints.
class ApiChatDataSource {
  final ApiClient _api;
  final String _currentUserId;

  ApiChatDataSource({
    required ApiClient apiClient,
    required String currentUserId,
  })  : _api = apiClient,
        _currentUserId = currentUserId;

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[Qent Chat] $message');
    }
  }

  /// Create or retrieve an existing conversation for a car listing.
  /// [otherUserId] is the other party — host if caller is renter, renter if caller is host.
  Future<Chat> getOrCreateConversation(String carId, String otherUserId) async {
    _log('getOrCreateConversation carId=$carId otherUserId=$otherUserId');

    final response = await _api.post(
      '/chat/conversations',
      body: {
        'car_id': carId,
        'other_user_id': otherUserId,
      },
    );

    if (!response.isSuccess) {
      _log('getOrCreateConversation failed: ${response.errorMessage}');
      throw Exception(response.errorMessage);
    }

    final data = response.body as Map<String, dynamic>;
    _log('getOrCreateConversation OK id=${data['id']}');
    return _conversationToChat(data);
  }

  /// Fetch all conversations for the current user.
  Future<List<Chat>> getConversations() async {
    _log('getConversations');

    final response = await _api.get('/chat/conversations');

    if (!response.isSuccess) {
      _log('getConversations failed: ${response.errorMessage}');
      throw Exception(response.errorMessage);
    }

    final list = response.body as List<dynamic>;
    _log('getConversations OK count=${list.length}');

    return list
        .map((item) => _conversationToChat(item as Map<String, dynamic>))
        .toList();
  }

  /// Fetch messages for a conversation.
  Future<List<ChatMessage>> getMessages(String conversationId) async {
    _log('getMessages conversationId=$conversationId');

    final response = await _api.get(
      '/chat/conversations/$conversationId/messages',
    );

    if (!response.isSuccess) {
      _log('getMessages failed: ${response.errorMessage}');
      throw Exception(response.errorMessage);
    }

    final list = response.body as List<dynamic>;
    _log('getMessages OK count=${list.length}');

    return list
        .map((item) => _messageFromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Send a message in a conversation.
  Future<ChatMessage> sendMessage(
    String conversationId,
    String content, {
    MessageType type = MessageType.text,
    String? replyToId,
  }) async {
    _log('sendMessage conversationId=$conversationId type=${type.name}');

    final body = <String, dynamic>{
      'content': content,
      'message_type': type.name,
    };
    if (replyToId != null) {
      body['reply_to_id'] = replyToId;
    }

    final response = await _api.post(
      '/chat/conversations/$conversationId/messages',
      body: body,
    );

    if (!response.isSuccess) {
      _log('sendMessage failed: ${response.errorMessage}');
      throw Exception(response.errorMessage);
    }

    final data = response.body as Map<String, dynamic>;
    _log('sendMessage OK id=${data['id']}');
    return _messageFromJson(data);
  }

  /// Delete a conversation and all its messages.
  Future<void> deleteConversation(String conversationId) async {
    _log('deleteConversation conversationId=$conversationId');

    final response = await _api.delete(
      '/chat/conversations/$conversationId',
    );

    if (!response.isSuccess) {
      _log('deleteConversation failed: ${response.errorMessage}');
      throw Exception(response.errorMessage);
    }

    _log('deleteConversation OK');
  }

  /// Mark all messages in a conversation as read.
  Future<void> markAsRead(String conversationId) async {
    _log('markAsRead conversationId=$conversationId');

    final response = await _api.post(
      '/chat/conversations/$conversationId/read',
    );

    if (!response.isSuccess) {
      _log('markAsRead failed: ${response.errorMessage}');
      throw Exception(response.errorMessage);
    }

    _log('markAsRead OK');
  }

  // ---------------------------------------------------------------------------
  // JSON mapping helpers
  // ---------------------------------------------------------------------------

  /// Map API conversation JSON to [Chat] model.
  Chat _conversationToChat(Map<String, dynamic> data) {
    // Determine which side the current user is on so we can pick the correct
    // unread count and identify the other user.
    final renterId = (data['renter_id'] ?? '').toString();
    final hostId = (data['host_id'] ?? '').toString();
    final isRenter = _currentUserId == renterId;

    final unreadCount = isRenter
        ? _intFromJson(data['renter_unread_count'])
        : _intFromJson(data['host_unread_count']);

    // The other user's id is the one that is NOT the current user.
    final otherUserId = isRenter ? hostId : renterId;

    return Chat(
      id: (data['id'] ?? '').toString(),
      userId: otherUserId,
      userName: (data['other_user_name'] ?? '').toString(),
      userImageUrl: '', // ProfileImageWidget uses userId directly
      lastMessage: (data['last_message_text'] ?? '').toString(),
      lastMessageTime: _dateFromJson(data['last_message_at']),
      unreadCount: unreadCount,
      isOnline: false,
      carId: data['car_id']?.toString(),
      carName: (data['car_name'] ?? '').toString(),
      isPartner: (data['other_user_role'] ?? '') == 'host',
    );
  }

  /// Map API message JSON to [ChatMessage] model.
  ChatMessage _messageFromJson(Map<String, dynamic> data) {
    return ChatMessage(
      id: (data['id'] ?? '').toString(),
      chatId: (data['conversation_id'] ?? '').toString(),
      senderId: (data['sender_id'] ?? '').toString(),
      senderName: (data['sender_name'] ?? '').toString(),
      senderImageUrl: '', // ProfileImageWidget uses senderId directly
      message: (data['content'] ?? '').toString(),
      timestamp: _dateFromJson(data['created_at']),
      type: _messageTypeFromJson(data['message_type']),
      isRead: data['is_read'] == true,
      replyTo: null, // Reply info resolved separately if needed
    );
  }

  /// Parse an ISO-8601 date string, falling back to [DateTime.now].
  DateTime _dateFromJson(dynamic value) {
    if (value == null) return DateTime.now();
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      _log('Failed to parse date: $value');
      return DateTime.now();
    }
  }

  /// Safely parse an int from JSON (could be int, double, String, or null).
  int _intFromJson(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  /// Map a string message type to the [MessageType] enum.
  MessageType _messageTypeFromJson(dynamic value) {
    final str = (value ?? 'text').toString();
    return MessageType.values.firstWhere(
      (e) => e.name == str,
      orElse: () => MessageType.text,
    );
  }
}
