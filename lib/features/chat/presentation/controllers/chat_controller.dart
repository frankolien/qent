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

  /// Update a pending entry in place — used by the voice/image send path
  /// when the upload finishes and we need to swap the local-file URL for
  /// the real CDN URL, and flip status from `uploading` to `sending`.
  void updateEntry(String tempId, ChatMessage Function(ChatMessage) update) {
    state = [
      for (final m in state)
        if (m.id == tempId) update(m) else m,
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
/// message.
///
/// Preferred path: match on `clientId`. Both rows carry the same
/// client-generated UUID, so the match is exact and one-to-one — no
/// false positives even if the user sent the same text twice. This is
/// the same idempotency-key pattern Slack/Stripe use.
///
/// Fallback path (legacy / pre-clientId messages): match on
/// (senderId, content, type) within a short time window. Kept for
/// safety but should rarely trigger once the new flow is live.
bool _isConfirmedBy(ChatMessage pending, ChatMessage server) {
  final pid = pending.clientId;
  final sid = server.clientId;
  if (pid != null && pid.isNotEmpty && sid != null && sid.isNotEmpty) {
    return pid == sid;
  }

  if (pending.senderId != server.senderId) return false;
  if (pending.type != server.type) return false;
  // For media messages the optimistic `message` is a local file path while
  // server `message` is the CDN URL — content compare won't match. Skip
  // the heuristic for media and rely on clientId once the server learns
  // about it; legacy server data won't have media duplicates anyway.
  if (pending.type != MessageType.text) return false;
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
        // Both `uploading` and `sending` are in-flight states the server
        // could legitimately confirm (a media message that finished
        // uploading and was POSTed, or a text message mid-API-call).
        if (p.status != MessageStatus.sending &&
            p.status != MessageStatus.uploading) {
          continue;
        }
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
      if (p.status == MessageStatus.sending ||
          p.status == MessageStatus.uploading) {
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
  /// failed on error.
  ///
  /// [clientId] is generated here if not supplied. It's the idempotency
  /// key sent to the backend AND the matching key used by
  /// `chatMessagesProvider` to swap the optimistic row for the server row
  /// once it arrives via stream refetch.
  ///
  /// [localPath] is set by the voice/image send paths so the optimistic
  /// bubble can play/render the local file while the upload is still in
  /// flight (or before it even starts). For text messages it's null.
  Future<void> sendMessage({
    required String chatId,
    required String message,
    MessageType type = MessageType.text,
    String? replyToMessageId,
    ReplyInfo? replyTo,
    String? clientId,
    String? localPath,
  }) async {
    final auth = _ref.read(authControllerProvider);
    final userId = auth.user?.uid ?? '';
    final senderName = auth.user?.fullName ?? '';

    // tempId is the local-only id used to address this row in the pending
    // state. clientId is the public idempotency key the server sees. They
    // share the same UUID for simplicity.
    final cid = clientId ?? _generateClientId();
    final tempId = 'pending_$cid';
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
      clientId: cid,
      localPath: localPath,
    );

    final pending = _ref.read(pendingMessagesProvider(chatId).notifier);
    pending.add(optimistic);

    try {
      await _dataSource.sendMessage(
        chatId,
        message,
        type: type,
        replyToId: replyToMessageId,
        clientId: cid,
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

  /// Generate a UUID-ish string. We don't pull in the `uuid` package just
  /// for this — a microsecond timestamp + a random suffix is plenty unique
  /// for an idempotency key that lives ~minutes server-side.
  String _generateClientId() {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final rand = (ts * 2654435761) & 0x7fffffff;
    return 'c_${ts.toRadixString(36)}_${rand.toRadixString(36)}';
  }

  /// Send a media (voice/image) message with full optimistic UX:
  /// 1. Insert a pending bubble *before* the upload starts, using the local
  ///    file path so the sender can play/render their own message
  ///    immediately. Status = uploading.
  /// 2. Run the upload via [uploadFn].
  /// 3. On upload complete: swap the local path for the CDN URL on the
  ///    same pending entry and flip status to sending. Fire the API call.
  /// 4. The chatMessagesProvider auto-confirms via clientId match once the
  ///    server response is fetched.
  ///
  /// On any failure (upload or API), mark the entry failed so the user
  /// can retry. The local file stays on disk until the message is
  /// confirmed or explicitly dismissed.
  Future<void> sendMediaMessage({
    required String chatId,
    required String localPath,
    required MessageType type,
    required Future<String?> Function() uploadFn,
  }) async {
    final auth = _ref.read(authControllerProvider);
    final userId = auth.user?.uid ?? '';
    final senderName = auth.user?.fullName ?? '';

    final cid = _generateClientId();
    final tempId = 'pending_$cid';
    final optimistic = ChatMessage(
      id: tempId,
      chatId: chatId,
      senderId: userId,
      senderName: senderName,
      senderImageUrl: '',
      // While uploading, `message` carries the local path so any UI that
      // reads `message` directly still has something to play. Once the
      // upload completes we overwrite this with the CDN URL.
      message: localPath,
      timestamp: DateTime.now(),
      type: type,
      isRead: false,
      status: MessageStatus.uploading,
      clientId: cid,
      localPath: localPath,
    );

    final pending = _ref.read(pendingMessagesProvider(chatId).notifier);
    pending.add(optimistic);

    String? uploadedUrl;
    try {
      uploadedUrl = await uploadFn();
    } catch (e) {
      debugPrint('[Qent Chat] media upload failed: $e');
      pending.markFailed(tempId);
      rethrow;
    }

    if (uploadedUrl == null) {
      pending.markFailed(tempId);
      throw Exception('Upload returned no URL');
    }

    // Upload done — flip status to sending and swap message to the CDN URL.
    pending.updateEntry(
      tempId,
      (m) => m.copyWith(message: uploadedUrl!, status: MessageStatus.sending),
    );

    try {
      await _dataSource.sendMessage(
        chatId,
        uploadedUrl,
        type: type,
        clientId: cid,
      );
      _ref.invalidate(messagesStreamProvider(chatId));
      _ref.invalidate(messagesProvider(chatId));
      _ref.invalidate(chatsStreamProvider);
      _ref.invalidate(chatsProvider);
    } catch (e) {
      debugPrint('[Qent Chat] media sendMessage failed: $e');
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
