import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/core/services/api_client.dart';
import 'package:qent/core/services/file_upload_service.dart';
import 'package:qent/core/services/websocket_service.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart';
import 'package:qent/features/chat/data/datasources/api_chat_datasource.dart';
import 'package:qent/features/chat/data/datasources/chat_cache.dart';
import 'package:qent/features/chat/domain/models/chat.dart';

// API chat datasource provider
final apiChatDataSourceProvider = Provider<ApiChatDataSource>((ref) {
  final authState = ref.watch(authControllerProvider);
  final userId = authState.user?.uid ?? '';
  return ApiChatDataSource(apiClient: ApiClient(), currentUserId: userId);
});

// All four providers below use `ref.keepAlive()` so they cache for the
// lifetime of the app session. Re-entering a chat (or the messages list)
// returns instantly from the cached value instead of triggering a fresh
// REST round-trip — same model as Instagram / WhatsApp / Telegram do
// with their on-disk caches. Real-time freshness comes from WebSocket
// frames mutating provider state. On reconnect we explicitly invalidate
// to catch any frames missed during the disconnect window.
//
// To force a refetch: call `ref.invalidate(...)`. That happens on:
//   - User-initiated pull-to-refresh
//   - WS reconnect (transition disconnected → connected)
//   - Send-related events that need fresh `last_message_text` for the
//     conversations list

final chatsProvider = FutureProvider<List<Chat>>((ref) async {
  ref.keepAlive();
  final dataSource = ref.watch(apiChatDataSourceProvider);
  final cache = ref.watch(chatCacheProvider);
  // FutureProvider can only emit one value, so we have to wait for the
  // network. Use the cache as a fast fallback if the network errors.
  // The StreamProvider variant below is what the UI actually watches
  // and gets the cache-first behaviour.
  try {
    final fresh = await dataSource.getConversations();
    unawaited(cache.replaceConversations(fresh));
    return fresh;
  } catch (e) {
    final cached = await cache.getConversations();
    if (cached.isNotEmpty) {
      debugPrint('[chatsProvider] network failed, serving ${cached.length} cached');
      return cached;
    }
    rethrow;
  }
});

// Cache-first stream: yield the on-disk snapshot immediately so the UI
// renders without waiting for the network, then yield the fresh server
// snapshot once REST returns. Cache is overwritten on success so the
// next read is up-to-date. We deliberately let exceptions propagate
// instead of yielding `[]` — the page treats `[]` as "no conversations"
// which is indistinguishable from a network/auth failure.
final chatsStreamProvider = StreamProvider<List<Chat>>((ref) async* {
  ref.keepAlive();
  final dataSource = ref.watch(apiChatDataSourceProvider);
  final cache = ref.watch(chatCacheProvider);

  final cached = await cache.getConversations();
  if (cached.isNotEmpty) {
    yield cached;
  }
  try {
    final fresh = await dataSource.getConversations();
    yield fresh;
    unawaited(cache.replaceConversations(fresh));
  } catch (e) {
    if (cached.isEmpty) rethrow;
    debugPrint('[chatsStreamProvider] network failed, keeping cached');
  }
});

final messagesProvider =
    FutureProvider.family<List<ChatMessage>, String>((ref, conversationId) async {
  ref.keepAlive();
  final dataSource = ref.watch(apiChatDataSourceProvider);
  final cache = ref.watch(chatCacheProvider);
  try {
    final fresh = await dataSource.getMessages(conversationId);
    unawaited(cache.replaceMessages(conversationId, fresh));
    return fresh;
  } catch (e) {
    final cached = await cache.getMessages(conversationId);
    if (cached.isNotEmpty) return cached;
    rethrow;
  }
});

final messagesStreamProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, conversationId) async* {
  ref.keepAlive();
  final dataSource = ref.watch(apiChatDataSourceProvider);
  final cache = ref.watch(chatCacheProvider);

  final cached = await cache.getMessages(conversationId);
  if (cached.isNotEmpty) {
    yield cached;
  }
  try {
    final fresh = await dataSource.getMessages(conversationId);
    yield fresh;
    unawaited(cache.replaceMessages(conversationId, fresh));
  } catch (e) {
    if (cached.isEmpty) rethrow;
    debugPrint('[messagesStreamProvider] network failed for $conversationId, keeping cached');
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
  List<ChatMessage> build() {
    // Keep alive across screen pops. We rely on this for the in-place
    // pending confirmation flow: a message you sent lives in
    // pendingMessagesProvider with status=sent until the next REST
    // poll moves it into the server snapshot.
    ref.keepAlive();

    // Hydrate from the on-disk outbox. This covers the force-close case:
    // user taps send → optimistic added → app killed before WS echo
    // confirms → on next launch (or chat re-open) the entry is loaded
    // back from disk so the message doesn't visually disappear.
    Future.microtask(() async {
      final cache = ref.read(chatCacheProvider);
      final loaded = await cache.getPendingMessages(conversationId);
      if (loaded.isEmpty) return;
      final existingIds = state.map((m) => m.id).toSet();
      final newOnes = loaded.where((m) => !existingIds.contains(m.id)).toList();
      if (newOnes.isEmpty) return;
      state = [...state, ...newOnes];
      // Re-fire any "sending" entries through the HTTP path. Server
      // dedupes via client_id, so if the original send had actually
      // landed before the app was killed, we just get the existing
      // row back and confirmByClientId flips the bubble to ✓.
      final controller = ref.read(chatControllerProvider);
      for (final m in newOnes) {
        if (m.status == MessageStatus.sending && m.type == MessageType.text) {
          // Fire-and-forget; don't block the UI
          unawaited(controller.resumePendingTextSend(m));
        }
      }
    });

    return const [];
  }

  void add(ChatMessage message) {
    state = [...state, message];
    unawaited(ref.read(chatCacheProvider).upsertPendingMessage(message));
  }

  void markFailed(String tempId) {
    ChatMessage? updated;
    state = [
      for (final m in state)
        if (m.id == tempId) ...[
          () {
            final u = m.copyWith(status: MessageStatus.failed);
            updated = u;
            return u;
          }(),
        ] else
          m,
    ];
    if (updated != null) {
      unawaited(ref.read(chatCacheProvider).upsertPendingMessage(updated!));
    }
  }

  /// Update a pending entry in place — used by the voice/image send path
  /// when the upload finishes and we need to swap the local-file URL for
  /// the real CDN URL, and flip status from `uploading` to `sending`.
  void updateEntry(String tempId, ChatMessage Function(ChatMessage) update) {
    ChatMessage? updated;
    state = [
      for (final m in state)
        if (m.id == tempId) ...[
          () {
            final u = update(m);
            updated = u;
            return u;
          }(),
        ] else
          m,
    ];
    if (updated != null) {
      unawaited(ref.read(chatCacheProvider).upsertPendingMessage(updated!));
    }
  }

  void remove(String tempId) {
    state = state.where((m) => m.id != tempId).toList();
    unawaited(ref.read(chatCacheProvider).deletePendingMessage(tempId));
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
    ChatMessage? confirmedRow;
    state = [
      for (final m in state)
        if (m.clientId == clientId && m.status != MessageStatus.sent) ...[
          () {
            found = true;
            final updated = m.copyWith(
              id: serverId,
              status: MessageStatus.sent,
              timestamp: serverTimestamp,
            );
            confirmedRow = updated;
            return updated;
          }(),
        ] else
          m,
    ];
    if (confirmedRow != null) {
      // Persist the confirmed row to disk (messages table) so it
      // survives an app restart even before the next REST refetch
      // moves it into the server snapshot.
      unawaited(ref.read(chatCacheProvider).upsertMessage(confirmedRow!));
      // Drop the outbox row — it's confirmed now, no need to retry
      // on next launch. Match by clientId since confirmByClientId
      // replaces the local id with the server's id.
      unawaited(ref.read(chatCacheProvider).deletePendingByClientId(clientId));
    }
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
  // Identity of the server list we last synced from the stream. Used to
  // detect a *new* stream emission vs a rebuild caused by something else
  // (pending changes, etc). Without this, every rebuild re-ran
  // `_lastServer = server` and clobbered any messages we'd added via
  // `appendServerMessage` from WebSocket events — symptom: the other
  // party's last message disappeared the moment you sent a reply.
  List<ChatMessage>? _lastSyncedServerRef;

  @override
  AsyncValue<List<ChatMessage>> build() {
    // Keep the provider alive across screen pops so reopening a chat
    // shows the cached messages immediately instead of skeleton-flashing
    // while REST refetches over slow cellular.
    ref.keepAlive();
    final serverAsync = ref.watch(messagesStreamProvider(conversationId));
    final pending = ref.watch(pendingMessagesProvider(conversationId));

    serverAsync.whenData((server) {
      // Identity guard: only resync from the stream when it actually
      // emits a new snapshot. On rebuilds triggered by pending changes,
      // `server` is the same list reference and we must NOT overwrite
      // _lastServer (which may have grown via appendServerMessage).
      if (identical(server, _lastSyncedServerRef)) return;
      _lastSyncedServerRef = server;
      debugPrint('[Recv] REST snapshot convo=$conversationId count=${server.length}');
      // Merge the fresh server snapshot with anything we appended via
      // WebSocket since the last sync. Any WS-appended message that the
      // fresh snapshot already contains (matched by id) is dropped from
      // the in-memory list — the server is now the truth for that row.
      final freshIds = <String>{for (final m in server) m.id};
      final extras = [
        for (final m in _lastServer)
          if (!freshIds.contains(m.id)) m,
      ];
      _lastServer = extras.isEmpty ? server : [...server, ...extras]
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
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

    // Persist to the on-disk cache so the message survives an app
    // restart. Fire-and-forget — the in-memory state is already
    // correct; sqflite is the slow path.
    unawaited(ref.read(chatCacheProvider).upsertMessage(message));
  }

  /// The other party in this conversation just opened the chat and
  /// marked everything from us as read. Flip `isRead = true` on every
  /// outgoing message in the cached snapshot so bubbles update from
  /// double-grey-tick to double-blue-tick immediately.
  void markMessagesReadByOtherParty(String readerId) {
    if (_lastServer.isEmpty) return;
    var changed = false;
    final next = <ChatMessage>[];
    for (final m in _lastServer) {
      // Only flip messages WE sent (recipient = readerId, sender = us).
      // The reader's own messages don't need updating.
      if (m.senderId != readerId && !m.isRead) {
        next.add(m.copyWith(isRead: true));
        changed = true;
      } else {
        next.add(m);
      }
    }
    if (!changed) return;
    _lastServer = next;
    final pending = ref.read(pendingMessagesProvider(conversationId));
    state = AsyncValue.data(_mergeWith(_lastServer, pending));
    // Best-effort persist; ignore errors.
    final cache = ref.read(chatCacheProvider);
    for (final m in _lastServer) {
      if (m.isRead && m.senderId != readerId) {
        unawaited(cache.upsertMessage(m));
      }
    }
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

  /// In-memory retry counter for outbox sends. Reset on app restart
  /// (which is fine — we WANT to retry from scratch after restart) and
  /// reset on success. Caps how many times we hammer the server before
  /// giving up and showing the red error icon to the user.
  final Map<String, int> _retryAttempts = {};
  static const int _maxRetryAttempts = 5;
  // Timers for scheduled exponential-backoff retries, keyed by tempId
  // so we can cancel them on success or chat dispose.
  final Map<String, Timer> _retryTimers = {};

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
    _retryTimers.remove(tempId)?.cancel();
    _retryAttempts.remove(tempId);
    _ref.read(pendingMessagesProvider(chatId).notifier).remove(tempId);
  }

  /// Re-fire an outbox-hydrated optimistic send through the HTTP path.
  /// Used when the app was force-closed mid-send (entry loaded from
  /// disk on launch) and on WS reconnect (network came back; flush the
  /// outbox).
  ///
  /// Handles all three media types:
  ///   - text: straight HTTP send with the existing client_id
  ///   - voice/image with status=sending: upload already completed
  ///     (the `message` field holds the CDN URL); just resend
  ///   - voice/image with status=uploading: re-attempt the upload from
  ///     `localPath` if the file still exists, then send. If the file
  ///     is gone (temp-dir cleanup, etc.) we mark failed so the user
  ///     can re-record.
  ///
  /// Server dedupes by client_id, so a successful original send + a
  /// resume attempt is a no-op on the server side (returns the
  /// existing row).
  ///
  /// Failures are retried with exponential backoff (1s, 2s, 4s, 8s,
  /// 16s capped at 60s) up to [_maxRetryAttempts] times before giving
  /// up and surfacing the red-error icon.
  Future<void> resumePending(ChatMessage pending) async {
    final cid = pending.clientId;
    if (cid == null || cid.isEmpty) return;

    // Bail if the user dismissed the failed entry (or it was already
    // confirmed) since this resume attempt was scheduled. Without this
    // guard we'd resurrect dismissed messages on a stale retry timer.
    final stillPresent = _ref
        .read(pendingMessagesProvider(pending.chatId))
        .any((m) => m.id == pending.id);
    if (!stillPresent) {
      debugPrint('[Send] resume: entry $pending.id no longer pending — skip');
      _retryAttempts.remove(pending.id);
      _retryTimers.remove(pending.id)?.cancel();
      return;
    }

    // Cancel any scheduled retry for this entry — we're attempting now.
    _retryTimers.remove(pending.id)?.cancel();

    debugPrint('[Send] resume outbox cid=$cid chat=${pending.chatId} type=${pending.type.name} status=${pending.status.name}');

    try {
      // Resolve the content to send. For uploading-state media, run the
      // upload first. For everything else, message already holds either
      // the text or the CDN URL.
      String content = pending.message;
      if (pending.type != MessageType.text &&
          pending.status == MessageStatus.uploading) {
        final localPath = pending.localPath;
        if (localPath == null || localPath.isEmpty) {
          throw Exception('media outbox entry has no localPath');
        }
        final file = File(localPath);
        if (!await file.exists()) {
          // Temp dir was cleared since the original send. Can't
          // resurrect — mark failed permanently and stop.
          debugPrint('[Send] resume: local file gone, giving up cid=$cid');
          _retryAttempts.remove(pending.id);
          _ref
              .read(pendingMessagesProvider(pending.chatId).notifier)
              .markFailed(pending.id);
          return;
        }
        final uploadedUrl = await FileUploadService.upload(file);
        if (uploadedUrl == null) {
          throw Exception('upload returned null');
        }
        content = uploadedUrl;
        // Flip the optimistic entry to status=sending with the CDN URL,
        // so subsequent crashes resume from the cheaper "just send"
        // branch instead of re-uploading.
        _ref
            .read(pendingMessagesProvider(pending.chatId).notifier)
            .updateEntry(pending.id, (m) => m.copyWith(
                  message: uploadedUrl,
                  status: MessageStatus.sending,
                ));
      }

      final confirmed = await _dataSource.sendMessage(
        pending.chatId,
        content,
        type: pending.type,
        replyToId: pending.replyTo?.messageId,
        clientId: cid,
      );
      _ref
          .read(pendingMessagesProvider(pending.chatId).notifier)
          .confirmByClientId(
            clientId: cid,
            serverId: confirmed.id,
            serverTimestamp: confirmed.timestamp,
          );
      _retryAttempts.remove(pending.id);
      _ref.invalidate(chatsStreamProvider);
    } catch (e) {
      debugPrint('[Send] resume failed cid=$cid err=$e');
      final attempts = (_retryAttempts[pending.id] ?? 0) + 1;
      _retryAttempts[pending.id] = attempts;
      if (attempts >= _maxRetryAttempts) {
        debugPrint('[Send] resume: gave up after $attempts attempts cid=$cid');
        _retryAttempts.remove(pending.id);
        _ref
            .read(pendingMessagesProvider(pending.chatId).notifier)
            .markFailed(pending.id);
        return;
      }
      // Exponential backoff: 1s, 2s, 4s, 8s, 16s — capped at 60s.
      final delaySec = math.min(60, 1 << attempts);
      debugPrint('[Send] resume: retry $attempts/$_maxRetryAttempts in ${delaySec}s cid=$cid');
      _retryTimers[pending.id] = Timer(Duration(seconds: delaySec), () {
        // Fetch the latest version of the pending entry — its status
        // or content might have changed in the interim.
        final latest = _ref
            .read(pendingMessagesProvider(pending.chatId))
            .firstWhere(
              (m) => m.id == pending.id,
              orElse: () => pending,
            );
        unawaited(resumePending(latest));
      });
    }
  }

  /// Backwards-compatible wrapper kept for [PendingMessages] hydration.
  Future<void> resumePendingTextSend(ChatMessage pending) =>
      resumePending(pending);

  /// Drain the entire outbox across all conversations. Called at app
  /// launch (after auth) and on WebSocket reconnect — both are moments
  /// when "the network might have just come back" and any orphaned
  /// optimistic sends from a previous session should be retried.
  Future<void> resumeAllPending() async {
    final cache = _ref.read(chatCacheProvider);
    final all = await cache.getAllPendingMessages();
    if (all.isEmpty) return;
    debugPrint('[Send] resumeAllPending: ${all.length} outbox entries');
    // Group by conversation so we can also seed pendingMessagesProvider
    // state for any chats the user hasn't opened yet. Reading the
    // notifier triggers build() which hydrates from disk and fires
    // resume for sending-status entries.
    final convoIds = all.map((m) => m.chatId).toSet();
    for (final convoId in convoIds) {
      // ignore: unused_result
      _ref.read(pendingMessagesProvider(convoId));
    }
    // For entries that didn't go through the per-convo build path
    // (they did — but belt-and-suspenders), also retry directly.
    for (final m in all) {
      if (m.status == MessageStatus.sending ||
          m.status == MessageStatus.uploading) {
        unawaited(resumePending(m));
      }
    }
  }

  Future<void> markAsRead(String chatId) async {
    // Clear the cached unread count immediately so the blue badge in
    // the chat list disappears without waiting on the HTTP round-trip
    // (or the next /conversations refetch). The server call below is
    // the authoritative reset; this is just the optimistic mirror.
    unawaited(_ref.read(chatCacheProvider).clearUnread(chatId));
    _ref.invalidate(chatsStreamProvider);
    _ref.invalidate(chatsProvider);
    try {
      await _dataSource.markAsRead(chatId);
    } catch (e) {
      debugPrint('[Qent Chat] Error marking as read: $e');
    }
  }

  Future<void> deleteConversation(String chatId) async {
    await _dataSource.deleteConversation(chatId);
    // Drop from the on-disk cache too — otherwise the deleted thread
    // ghost-shows up on the next app launch until REST refetches.
    unawaited(_ref.read(chatCacheProvider).deleteConversation(chatId));
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
  ref.keepAlive();
  final dataSource = ref.watch(apiChatDataSourceProvider);
  final controller = ChatController(dataSource, ref);

  // Drain the outbox once on first creation. This is the post-launch
  // catch-up path — any pending optimistic sends from a previous app
  // session get re-fired here without the user having to open each
  // affected chat.
  Future.microtask(() => controller.resumeAllPending());

  // Also flush the outbox on every WebSocket reconnect: that's when
  // "the network just came back" so any sends that failed while
  // offline are due for another try. We poll the WS state every
  // second — cheaper than wiring a state stream on the WS service.
  final ws = ref.read(wsServiceProvider);
  var lastState = ws.state;
  final wsTicker = Timer.periodic(const Duration(seconds: 1), (_) {
    final cur = ws.state;
    if (cur == WsState.connected && lastState != WsState.connected) {
      debugPrint('[Send] WS reconnected — flushing outbox');
      controller.resumeAllPending();
    }
    lastState = cur;
  });

  // Global WS event listener for chat-list freshness. When ANY message
  // arrives over WS — regardless of whether the user is on the chat
  // detail page, the messages list, or somewhere else entirely — the
  // chats list's last_message_text and unread_count are out of date.
  // Invalidate the conversations stream so it re-emits with fresh
  // data. Combined with the cache-first read, the user sees the
  // updated last-message preview without ever waiting on a poll.
  // (Replaces the 5-second polling that used to live in messages_page.)
  final wsEventSub = ws.events.listen((event) {
    if (event.type == 'new_message') {
      // Bump the affected conversation in the cache FIRST so the next
      // chatsStreamProvider yield (cached) is already in the right
      // order — the user sees the chat float to the top instantly,
      // not after the REST round-trip lands. Without this, the cached
      // yield emits stale ordering and only the (slow) network yield
      // bubbles the chat up.
      final convoId = event.payload['conversation_id']?.toString();
      final content = event.payload['content']?.toString() ?? '';
      final senderId = event.payload['sender_id']?.toString();
      final auth = ref.read(authControllerProvider);
      final myId = auth.user?.uid;
      final isFromOther = senderId != null && myId != null && senderId != myId;
      if (convoId != null && convoId.isNotEmpty) {
        final ts = _parseWsTimestamp(event.payload['created_at']);
        unawaited(ref.read(chatCacheProvider).bumpConversation(
              conversationId: convoId,
              lastMessageText: content,
              lastMessageAt: ts,
              unreadDelta: isFromOther ? 1 : 0,
            ));
        // Also write the actual message into the messages cache, AND
        // append it into the in-memory chatMessagesProvider snapshot
        // (if that provider is alive). Without this, opening the chat
        // from the list shows yesterday's tail and "loads" the new
        // message visibly slowly while REST refetches — even though
        // the chat-list preview already showed it. The chat detail's
        // own WS handler still runs when that screen is mounted; this
        // is the global fallback for "user is anywhere else."
        final msg = _chatMessageFromGlobalWsPayload(event.payload);
        if (msg != null) {
          unawaited(ref.read(chatCacheProvider).upsertMessage(msg));
          // The keep-alive on chatMessagesProvider means once the user
          // has opened a chat this session, the provider stays alive
          // and this append lands instantly — opening the chat again
          // shows the new message with no REST round-trip. If they've
          // never opened it, this read constructs it; the cache write
          // above is what keeps that first open snappy.
          try {
            ref
                .read(chatMessagesProvider(convoId).notifier)
                .appendServerMessage(msg);
          } catch (_) {
            // best-effort
          }
        }
      }
      ref.invalidate(chatsStreamProvider);
      ref.invalidate(chatsProvider);
    } else if (event.type == 'message_read') {
      // The OTHER party opened our chat and marked our messages as
      // read. Flip is_read=true on every message we sent in this
      // conversation so bubbles update from double-grey-tick to
      // double-blue-tick immediately.
      final convoId = event.payload['conversation_id']?.toString();
      final readerId = event.payload['reader_id']?.toString();
      if (convoId != null && convoId.isNotEmpty && readerId != null) {
        ref
            .read(chatMessagesProvider(convoId).notifier)
            .markMessagesReadByOtherParty(readerId);
      }
    } else if (event.type == 'presence_update') {
      // Another user came online or went offline. Stash in the
      // shared presence map so bubble icons can switch between
      // single-grey-tick (offline) and double-grey-tick (online).
      final userId = event.payload['user_id']?.toString();
      final online = event.payload['online'] == true;
      if (userId != null && userId.isNotEmpty) {
        ref.read(presenceProvider.notifier).setOnline(userId, online);
      }
    } else if (event.type == 'presence_snapshot') {
      // Pushed by the server immediately after this device's WS
      // connects. Carries the full set of users that were already
      // online at that moment, so we don't have to wait for
      // per-user transition events to know who's reachable.
      final ids = event.payload['online_user_ids'];
      if (ids is List) {
        final next = <String, bool>{
          for (final id in ids)
            if (id is String && id.isNotEmpty) id: true,
        };
        ref.read(presenceProvider.notifier).replaceAll(next);
      }
    }
  });

  ref.onDispose(() {
    wsTicker.cancel();
    wsEventSub.cancel();
    for (final t in controller._retryTimers.values) {
      t.cancel();
    }
    controller._retryTimers.clear();
  });

  return controller;
});

/// Build a [ChatMessage] from a `new_message` WS payload. Mirrors the
/// version that lives in chat_detail_page (which has access to the
/// page's local sender_image lookup) — this one is used by the global
/// WS listener that runs regardless of which screen is on top, so it
/// only needs the fields the cache and chat-list snapshot care about.
ChatMessage? _chatMessageFromGlobalWsPayload(Map<String, dynamic> payload) {
  try {
    final id = (payload['id'] ?? '').toString();
    final convo = (payload['conversation_id'] ?? '').toString();
    final senderId = (payload['sender_id'] ?? '').toString();
    if (id.isEmpty || convo.isEmpty || senderId.isEmpty) return null;

    MessageType type;
    switch ((payload['message_type'] ?? 'text').toString()) {
      case 'voice':
        type = MessageType.voice;
        break;
      case 'image':
        type = MessageType.image;
        break;
      default:
        type = MessageType.text;
    }

    ReplyInfo? replyTo;
    final replyToId = payload['reply_to_id']?.toString();
    final replyToContent = payload['reply_to_content']?.toString();
    if (replyToId != null && replyToId.isNotEmpty && replyToContent != null) {
      MessageType replyType;
      switch ((payload['reply_to_message_type'] ?? 'text').toString()) {
        case 'voice':
          replyType = MessageType.voice;
          break;
        case 'image':
          replyType = MessageType.image;
          break;
        default:
          replyType = MessageType.text;
      }
      replyTo = ReplyInfo(
        messageId: replyToId,
        senderId: (payload['reply_to_sender_id'] ?? '').toString(),
        senderName: (payload['reply_to_sender_name'] ?? '').toString(),
        message: replyToContent,
        type: replyType,
      );
    }

    return ChatMessage(
      id: id,
      chatId: convo,
      senderId: senderId,
      senderName: (payload['sender_name'] ?? '').toString(),
      senderImageUrl: '',
      message: (payload['content'] ?? '').toString(),
      timestamp: _parseWsTimestamp(payload['created_at']),
      type: type,
      isRead: payload['is_read'] == true,
      replyTo: replyTo,
      clientId: payload['client_id']?.toString(),
    );
  } catch (_) {
    return null;
  }
}

/// Parse a server `created_at` timestamp from a WebSocket payload. The
/// backend serialises NaiveDateTime with no offset, so we treat it as
/// UTC. Falls back to "now" if the field is missing.
DateTime _parseWsTimestamp(dynamic raw) {
  if (raw == null) return DateTime.now();
  final s = raw.toString();
  if (s.isEmpty) return DateTime.now();
  final hasOffset = s.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(s);
  try {
    return DateTime.parse(hasOffset ? s : '${s}Z').toLocal();
  } catch (_) {
    return DateTime.now();
  }
}

/// Tracks which other users are currently online (have at least one WS
/// session connected to the backend). Populated by `presence_update`
/// events from the server. Bubble status icons read from this to flip
/// between single-grey-tick (recipient offline) and double-grey-tick
/// (recipient online but hasn't read yet).
class PresenceState extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() {
    ref.keepAlive();
    return const {};
  }

  void setOnline(String userId, bool online) {
    if (state[userId] == online) return;
    state = {...state, userId: online};
  }

  /// Bulk-set from a server snapshot — used after the chat list loads
  /// to seed online status for all known peers in one call.
  void replaceAll(Map<String, bool> next) {
    state = Map.unmodifiable(next);
  }

  bool isOnline(String userId) => state[userId] == true;
}

final presenceProvider =
    NotifierProvider<PresenceState, Map<String, bool>>(PresenceState.new);
