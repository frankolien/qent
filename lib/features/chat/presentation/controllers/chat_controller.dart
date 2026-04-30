import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/core/services/api_client.dart';
import 'package:qent/core/services/websocket_service.dart';
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

// For backward compat with the UI that uses chatsStreamProvider.
//
// We deliberately let exceptions propagate instead of yielding `[]`: the
// page treats `[]` as "user has no conversations" and shows the empty
// state, which is indistinguishable from a network/auth failure. By
// surfacing the error the page can show its retry UI.
final chatsStreamProvider = StreamProvider<List<Chat>>((ref) async* {
  final dataSource = ref.watch(apiChatDataSourceProvider);
  yield await dataSource.getConversations();
});

// FutureProvider for messages in a specific conversation
final messagesProvider = FutureProvider.family<List<ChatMessage>, String>((ref, conversationId) async {
  final dataSource = ref.watch(apiChatDataSourceProvider);
  return dataSource.getMessages(conversationId);
});

// For backward compat with the UI that uses messagesStreamProvider.
// Errors propagate so the page can show its retry UI instead of an
// indistinguishable empty state.
final messagesStreamProvider = StreamProvider.family<List<ChatMessage>, String>((ref, conversationId) async* {
  final dataSource = ref.watch(apiChatDataSourceProvider);
  yield await dataSource.getMessages(conversationId);
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

  /// Find a pending entry by its `clientId` and flip it to "confirmed":
  /// status=sent, real server id, server timestamp. Used when the WS
  /// echo or HTTP rescue returns for a message the user just sent.
  ///
  /// Why: the alternative is to add a *new* entry to the server snapshot
  /// and drop the pending one. That swap, even with stable widget keys,
  /// produces a visible flash because the optimistic and the server
  /// message have different ids, timestamps, and (sometimes) replyTo
  /// state — Flutter has to rebuild and relayout. Mutating in place
  /// keeps the same widget instance with the same key from optimistic
  /// add through final confirmation; the only visible change is the
  /// status icon flipping clock → check.
  ///
  /// Returns true if a pending entry was found and updated.
  bool confirmByClientId({
    required String clientId,
    required String serverId,
    required DateTime serverTimestamp,
  }) {
    var found = false;
    state = [
      for (final m in state)
        if (m.clientId == clientId && m.status != MessageStatus.sent) ...[
          () {
            found = true;
            return m.copyWith(
              id: serverId,
              status: MessageStatus.sent,
              timestamp: serverTimestamp,
            );
          }(),
        ] else
          m,
    ];
    return found;
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
    // Keep the provider alive across screen pops so reopening a chat
    // shows the cached messages immediately instead of skeleton-flashing
    // while REST refetches over slow cellular.
    ref.keepAlive();
    final serverAsync = ref.watch(messagesStreamProvider(conversationId));
    final pending = ref.watch(pendingMessagesProvider(conversationId));

    serverAsync.whenData((server) {
      debugPrint('[Recv] REST snapshot convo=$conversationId count=${server.length}');
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

  /// Append (or replace, if already present by id or client_id) a server
  /// message into the cached snapshot, then trigger a rebuild. This is
  /// what the WebSocket `new_message` handler calls — much faster than
  /// invalidating the messagesStreamProvider and refetching the whole
  /// list over HTTP.
  ///
  /// Idempotent: if the same id/client_id is already in `_lastServer`
  /// we replace in place instead of duplicating, so a delayed HTTP
  /// refetch arriving after the WS event is harmless.
  /// Cheap structural compare — true if the two messages would render
  /// identically. Used to skip rebuilds when the same `new_message`
  /// frame is broadcast more than once (server retransmits, our own
  /// HTTP rescue racing the WS echo, etc.). Anything that affects
  /// rendering must be in here.
  bool _sameMessage(ChatMessage a, ChatMessage b) {
    return a.id == b.id &&
        a.message == b.message &&
        a.timestamp == b.timestamp &&
        a.type == b.type &&
        a.isRead == b.isRead &&
        a.status == b.status &&
        a.clientId == b.clientId;
  }

  void appendServerMessage(ChatMessage message) {
    debugPrint('[Recv] appendServerMessage convo=$conversationId id=${message.id} cid=${message.clientId} sender=${message.senderId}');
    if (!_hasServerData) {
      _lastServer = [message];
      _hasServerData = true;
    } else {
      // Find existing by id (server-confirmed) or by clientId (when an
      // older snapshot saw it before its server id materialised).
      final existingIdx = _lastServer.indexWhere((m) {
        if (m.id == message.id) return true;
        final ac = message.clientId;
        return ac != null && ac.isNotEmpty && m.clientId == ac;
      });
      if (existingIdx >= 0) {
        // No-op fast path: incoming message is structurally identical to
        // the cached one. Skipping the state update here is what
        // eliminates the sub-second flash when the same WS frame gets
        // delivered twice (WS echo + HTTP rescue, or server retransmit).
        if (_sameMessage(_lastServer[existingIdx], message)) {
          debugPrint('[Recv] skip rebuild — identical to cached');
          return;
        }
        final next = List<ChatMessage>.from(_lastServer);
        next[existingIdx] = message;
        _lastServer = next;
      } else {
        _lastServer = [..._lastServer, message];
      }
    }

    // Drop the matching pending optimistic entry (if any) directly. The
    // merge function would also hide it, but explicitly removing it keeps
    // pendingMessagesProvider's state clean — otherwise stale "sending"
    // entries pile up across screen lifecycles, and the keep-alive on
    // chatMessagesProvider means they'd survive across chat reopens.
    final pending = ref.read(pendingMessagesProvider(conversationId));
    final cid = message.clientId;
    if (cid != null && cid.isNotEmpty) {
      final match = pending.where((p) => p.clientId == cid).toList();
      if (match.isNotEmpty) {
        debugPrint('[Recv] confirming ${match.length} pending entry/entries by clientId=$cid');
        final pendingNotifier =
            ref.read(pendingMessagesProvider(conversationId).notifier);
        // Defer to microtask: we're inside another notifier's build/append,
        // mutating sibling notifier state synchronously isn't safe.
        Future.microtask(() {
          for (final m in match) {
            pendingNotifier.remove(m.id);
          }
        });
      }
    }

    // Force the provider to re-emit so anyone watching gets the new list.
    state = AsyncValue.data(_mergeWith(_lastServer, pending));
  }

  List<ChatMessage> _mergeWith(
    List<ChatMessage> server,
    List<ChatMessage> pending,
  ) {
    if (pending.isEmpty) return server;
    // Build sets of server-side identifiers so we can cheaply drop any
    // pending entry that's already represented in the server snapshot
    // — covers two cases:
    //   1) Sent-then-refetched: our in-place-confirmed pending (status
    //      sent, id = server's id) shows up as a duplicate when the
    //      next REST poll returns it. Match by id and drop the pending.
    //   2) Sent-then-clientId-echoed (legacy / non-in-place): pending
    //      with status=sending matches a server entry by clientId.
    //      Match and drop.
    final serverIds = <String>{for (final m in server) m.id};
    final serverCids = <String>{
      for (final m in server)
        if (m.clientId != null && m.clientId!.isNotEmpty) m.clientId!,
    };
    final claimed = <int>{};
    final stillPending = <ChatMessage>[];
    for (final p in pending) {
      // Already in server by id? Drop.
      if (serverIds.contains(p.id)) continue;
      // Already in server by clientId? Drop.
      final pcid = p.clientId;
      if (pcid != null && pcid.isNotEmpty && serverCids.contains(pcid)) {
        continue;
      }
      // Legacy heuristic match (no clientIds on either side).
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
    debugPrint('[Send] optimistic added cid=$cid chat=$chatId type=${type.name}');

    // Fast path: send over WebSocket. The server inserts, dedupes by
    // client_id, and broadcasts a `new_message` back to us — the
    // chatMessagesProvider auto-confirms our optimistic row when that
    // arrives. No HTTP round-trip, no refetch. This is what makes chat
    // feel instant on slow networks.
    final ws = _ref.read(wsServiceProvider);
    final wsState = ws.state;
    debugPrint('[Send] ws.state=$wsState');
    final sentOverWs = ws.sendChatMessage(
      conversationId: chatId,
      content: message,
      messageType: type.name,
      clientId: cid,
      replyToId: replyToMessageId,
    );
    debugPrint('[Send] sentOverWs=$sentOverWs');

    if (sentOverWs) {
      // Bump the chat list now too — `last_message_text` will be stale
      // until the server-broadcast new_message round-trips.
      _ref.invalidate(chatsStreamProvider);
      _ref.invalidate(chatsProvider);
      // Safety net: if the WS echo doesn't return in 2.5s, also fire
      // HTTP. Idempotent via client_id, so no risk of duplicates if
      // both eventually land. The HTTP response invalidates the
      // messagesStreamProvider, which causes chatMessagesProvider to
      // confirm-and-remove the optimistic row even when the WS echo
      // got lost. Without this, a flaky WS leaves bubbles on the clock
      // icon indefinitely — the exact symptom the user is seeing.
      Future.delayed(const Duration(milliseconds: 2500), () async {
        final stillPending = _ref
            .read(pendingMessagesProvider(chatId))
            .any((m) => m.id == tempId && m.status == MessageStatus.sending);
        if (!stillPending) return;
        debugPrint('[Send] WS echo not in 2.5s for cid=$cid — HTTP rescue');
        try {
          final confirmed = await _dataSource.sendMessage(
            chatId,
            message,
            type: type,
            replyToId: replyToMessageId,
            clientId: cid,
          );
          // Confirm the pending entry IN PLACE (same widget, just status
          // icon flips). Falls back to appendServerMessage if the
          // pending entry has somehow already disappeared.
          final ok = pending.confirmByClientId(
            clientId: cid,
            serverId: confirmed.id,
            serverTimestamp: confirmed.timestamp,
          );
          if (!ok) {
            _ref
                .read(chatMessagesProvider(chatId).notifier)
                .appendServerMessage(confirmed);
          }
          _ref.invalidate(chatsStreamProvider);
        } catch (e) {
          debugPrint('[Send] HTTP rescue failed: $e');
          pending.markFailed(tempId);
        }
      });
      return;
    }

    // WS not connected — fall back to HTTP. Same idempotency key, so if
    // both somehow land the server dedupes.
    try {
      debugPrint('[Send] HTTP path POST /chat/.../messages cid=$cid');
      final confirmed = await _dataSource.sendMessage(
        chatId,
        message,
        type: type,
        replyToId: replyToMessageId,
        clientId: cid,
      );
      debugPrint('[Send] HTTP path OK cid=$cid id=${confirmed.id}');
      final ok = pending.confirmByClientId(
        clientId: cid,
        serverId: confirmed.id,
        serverTimestamp: confirmed.timestamp,
      );
      if (!ok) {
        _ref
            .read(chatMessagesProvider(chatId).notifier)
            .appendServerMessage(confirmed);
      }
      _ref.invalidate(chatsStreamProvider);
      _ref.invalidate(chatsProvider);
    } catch (e) {
      debugPrint('[Send] HTTP path FAILED cid=$cid err=$e');
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

    // Same fast path as text: try WebSocket first, with HTTP rescue if
    // the echo doesn't return.
    final ws = _ref.read(wsServiceProvider);
    final sentOverWs = ws.sendChatMessage(
      conversationId: chatId,
      content: uploadedUrl,
      messageType: type.name,
      clientId: cid,
    );
    if (sentOverWs) {
      _ref.invalidate(chatsStreamProvider);
      _ref.invalidate(chatsProvider);
      Future.delayed(const Duration(milliseconds: 2500), () async {
        final stillPending = _ref
            .read(pendingMessagesProvider(chatId))
            .any((m) => m.id == tempId && m.status == MessageStatus.sending);
        if (!stillPending) return;
        debugPrint('[Send media] WS echo not in 2.5s for cid=$cid — HTTP rescue');
        try {
          final confirmed = await _dataSource.sendMessage(
            chatId,
            uploadedUrl!,
            type: type,
            clientId: cid,
          );
          final ok = pending.confirmByClientId(
            clientId: cid,
            serverId: confirmed.id,
            serverTimestamp: confirmed.timestamp,
          );
          if (!ok) {
            _ref
                .read(chatMessagesProvider(chatId).notifier)
                .appendServerMessage(confirmed);
          }
          _ref.invalidate(chatsStreamProvider);
        } catch (e) {
          debugPrint('[Send media] HTTP rescue failed: $e');
          pending.markFailed(tempId);
        }
      });
      return;
    }

    try {
      final confirmed = await _dataSource.sendMessage(
        chatId,
        uploadedUrl,
        type: type,
        clientId: cid,
      );
      final ok = pending.confirmByClientId(
        clientId: cid,
        serverId: confirmed.id,
        serverTimestamp: confirmed.timestamp,
      );
      if (!ok) {
        _ref
            .read(chatMessagesProvider(chatId).notifier)
            .appendServerMessage(confirmed);
      }
      _ref.invalidate(chatsStreamProvider);
      _ref.invalidate(chatsProvider);
    } catch (e) {
      debugPrint('[Qent Chat] media sendMessage HTTP fallback failed: $e');
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
