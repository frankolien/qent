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

/// Local-only optimistic messages, keyed by conversation id. Each entry is
/// a message the user just sent that is still in flight (or has failed).
/// Once the server confirms the message, it disappears from this overlay
/// and shows up via [messagesStreamProvider] instead.
class PendingMessages extends Notifier<List<ChatMessage>> {
  PendingMessages(this.conversationId);

  final String conversationId;

  @override
  List<ChatMessage> build() => const [];

  void add(ChatMessage message) {
    state = [...state, message];
  }

  void markFailed(String tempId) {
    state = [
      for (final m in state)
        if (m.id == tempId) m.copyWith(status: MessageStatus.failed) else m,
    ];
  }

  void remove(String tempId) {
    state = state.where((m) => m.id != tempId).toList();
  }

  void clear() {
    state = const [];
  }
}

final pendingMessagesProvider =
    NotifierProvider.family<PendingMessages, List<ChatMessage>, String>(
  PendingMessages.new,
);

/// Whether a pending optimistic entry has been confirmed by a server
/// message. The server assigns a fresh UUID to the message, so we can't
/// match by id — we match on (senderId, content, type) within a short
/// time window. The window is generous to absorb clock skew and slow
/// networks, but tight enough that a near-duplicate from the same user
/// doesn't accidentally cancel a legitimately-pending send.
bool _isConfirmedBy(ChatMessage pending, ChatMessage server) {
  if (pending.senderId != server.senderId) return false;
  if (pending.type != server.type) return false;
  if (pending.message != server.message) return false;
  final delta = server.timestamp.difference(pending.timestamp).abs();
  return delta < const Duration(minutes: 2);
}

/// Merged view: server messages + local pending overlay.
///
/// Why this matters: when a send completes, we invalidate
/// [messagesStreamProvider] to refetch. During that refetch the stream
/// goes through a `loading` state, which previously flashed a skeleton
/// over the whole chat (very bad UX). To avoid that, we keep the last
/// known server snapshot here and only update it when a new `data` value
/// arrives. The merged result is therefore never `loading` after the
/// first successful fetch.
final chatMessagesProvider =
    NotifierProvider.family<ChatMessagesNotifier, AsyncValue<List<ChatMessage>>, String>(
  ChatMessagesNotifier.new,
);

class ChatMessagesNotifier
    extends Notifier<AsyncValue<List<ChatMessage>>> {
  ChatMessagesNotifier(this.conversationId);

  final String conversationId;

  List<ChatMessage> _lastServer = const [];
  bool _hasServerData = false;

  @override
  AsyncValue<List<ChatMessage>> build() {
    final serverAsync = ref.watch(messagesStreamProvider(conversationId));
    final pending = ref.watch(pendingMessagesProvider(conversationId));

    serverAsync.whenData((server) {
      _lastServer = server;
      _hasServerData = true;

      // Auto-confirm pending entries that the server now has. We do a
      // one-to-one greedy match so that if the user sent the same text
      // twice, two pending entries don't both get confirmed by a single
      // server message. Defer the mutation to a microtask — modifying
      // another notifier's state synchronously during build is unsafe.
      final claimed = <int>{};
      final toConfirm = <String>[];
      for (final p in pending) {
        if (p.status != MessageStatus.sending) continue;
        for (var i = 0; i < server.length; i++) {
          if (claimed.contains(i)) continue;
          if (_isConfirmedBy(p, server[i])) {
            claimed.add(i);
            toConfirm.add(p.id);
            break;
          }
        }
      }
      if (toConfirm.isNotEmpty) {
        Future.microtask(() {
          final n = ref.read(pendingMessagesProvider(conversationId).notifier);
          for (final id in toConfirm) {
            n.remove(id);
          }
        });
      }
    });

    // Until the very first server fetch lands, mirror the server state
    // (loading/error). After that, always serve the last good snapshot
    // merged with current pending — never go back to loading on refetch.
    if (!_hasServerData) {
      return serverAsync.whenData((server) => _mergeWith(server, pending));
    }
    return AsyncValue.data(_mergeWith(_lastServer, pending));
  }

  List<ChatMessage> _mergeWith(
    List<ChatMessage> server,
    List<ChatMessage> pending,
  ) {
    if (pending.isEmpty) return server;
    // Drop any pending entries the server already has, using the same
    // one-to-one greedy match used for confirmation, so duplicate sends
    // (same text twice) aren't both swallowed by a single server entry.
    final claimed = <int>{};
    final stillPending = <ChatMessage>[];
    for (final p in pending) {
      var matched = false;
      if (p.status == MessageStatus.sending) {
        for (var i = 0; i < server.length; i++) {
          if (claimed.contains(i)) continue;
          if (_isConfirmedBy(p, server[i])) {
            claimed.add(i);
            matched = true;
            break;
          }
        }
      }
      if (!matched) stillPending.add(p);
    }
    final merged = [...server, ...stillPending];
    merged.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return merged;
  }
}

// Chat controller for actions
class ChatController {
  final ApiChatDataSource _dataSource;
  final Ref _ref;

  ChatController(this._dataSource, this._ref);

  Future<Chat> getOrCreateConversation(String carId, String hostId) async {
    return await _dataSource.getOrCreateConversation(carId, hostId);
  }

  /// Send a message with optimistic UI: insert a local pending entry first,
  /// fire the API call, then drop the pending entry on success or flip it to
  /// failed on error. Server-confirmed message arrives via the WS
  /// `new_message` event which invalidates [messagesStreamProvider].
  Future<void> sendMessage({
    required String chatId,
    required String message,
    MessageType type = MessageType.text,
    String? replyToMessageId,
    ReplyInfo? replyTo,
  }) async {
    final auth = _ref.read(authControllerProvider);
    final userId = auth.user?.uid ?? '';
    final senderName = auth.user?.fullName ?? '';

    // Use a sentinel id prefix so the merge in chatMessagesProvider can
    // distinguish optimistic entries from server-confirmed ones; we remove
    // the optimistic entry by its tempId once the API call returns.
    final tempId = 'pending_${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = ChatMessage(
      id: tempId,
      chatId: chatId,
      senderId: userId,
      senderName: senderName,
      senderImageUrl: '',
      message: message,
      timestamp: DateTime.now(),
      type: type,
      isRead: false,
      replyTo: replyTo,
      status: MessageStatus.sending,
    );

    final pending = _ref.read(pendingMessagesProvider(chatId).notifier);
    pending.add(optimistic);

    try {
      await _dataSource.sendMessage(
        chatId,
        message,
        type: type,
        replyToId: replyToMessageId,
      );
      // We do NOT remove the optimistic entry here. The chatMessagesProvider
      // refetches on invalidate and removes pending entries automatically
      // once a matching server message arrives. Removing here would create
      // a brief gap where the message vanishes (refetch is async).
      _ref.invalidate(messagesStreamProvider(chatId));
      _ref.invalidate(messagesProvider(chatId));
      _ref.invalidate(chatsStreamProvider);
      _ref.invalidate(chatsProvider);
    } catch (e) {
      debugPrint('[Qent Chat] sendMessage failed: $e');
      pending.markFailed(tempId);
      rethrow;
    }
  }

  /// Retry a failed optimistic send. Removes the failed entry first so the
  /// new attempt gets a fresh tempId and timestamp.
  Future<void> retrySend({
    required String chatId,
    required ChatMessage failed,
  }) async {
    _ref.read(pendingMessagesProvider(chatId).notifier).remove(failed.id);
    await sendMessage(
      chatId: chatId,
      message: failed.message,
      type: failed.type,
      replyTo: failed.replyTo,
      replyToMessageId: failed.replyTo?.messageId,
    );
  }

  /// Drop a failed optimistic send without retrying.
  void dismissFailed({required String chatId, required String tempId}) {
    _ref.read(pendingMessagesProvider(chatId).notifier).remove(tempId);
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
