import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/core/services/websocket_service.dart';

/// Online status — derived from our own WebSocket connection state as
/// a stand-in for "the other user is reachable". A proper presence
/// protocol would have the backend broadcast user-online / user-offline
/// events; for now we reflect WS health, which is good enough for the
/// green-dot indicator (the only consumer of this value).
///
/// We avoid Timer.periodic — the WS service emits events whenever its
/// state changes, and the chatControllerProvider's per-second WS-state
/// poll is the single source of "did connection state flip" awareness.
/// Here we just emit the current state once and re-emit when chat WS
/// activity nudges the broadcaster (which happens on every reconnect
/// cycle as part of normal operation).
final onlineStatusStreamProvider = StreamProvider.family<bool, String>(
  (ref, userId) {
    final ws = ref.watch(wsServiceProvider);
    final controller = StreamController<bool>();

    void emit() {
      if (!controller.isClosed) {
        controller.add(ws.state == WsState.connected);
      }
    }

    // Emit initial state.
    emit();

    // Re-emit whenever any WS frame arrives — that's a reliable signal
    // that the connection is healthy and avoids the periodic timer.
    // On disconnect/reconnect the WS service rebuilds via auto-reconnect
    // and a fresh stream subscription gets created next time anyone
    // watches.
    final sub = ws.events.listen((_) => emit());

    ref.onDispose(() {
      sub.cancel();
      controller.close();
    });

    return controller.stream;
  },
);

/// Typing status — listens to WebSocket typing events for a conversation.
final typingStatusStreamProvider = StreamProvider.family<Map<String, bool>, String>(
  (ref, chatId) {
    final ws = ref.watch(wsServiceProvider);
    final controller = StreamController<Map<String, bool>>();
    final typingUsers = <String, bool>{};
    Timer? clearTimer;

    controller.add(typingUsers);

    final sub = ws.events.listen((event) {
      if (event.type == 'typing' && event.payload['conversation_id'] == chatId) {
        final userId = event.payload['user_id'] as String? ?? '';
        final isTyping = event.payload['is_typing'] == true;

        if (userId.isNotEmpty) {
          if (isTyping) {
            typingUsers[userId] = true;
          } else {
            typingUsers.remove(userId);
          }
          if (!controller.isClosed) {
            controller.add(Map.from(typingUsers));
          }

          // Auto-clear after 4 seconds if no stop event
          if (isTyping) {
            clearTimer?.cancel();
            clearTimer = Timer(const Duration(seconds: 4), () {
              typingUsers.remove(userId);
              if (!controller.isClosed) {
                controller.add(Map.from(typingUsers));
              }
            });
          }
        }
      }
    });

    ref.onDispose(() {
      sub.cancel();
      clearTimer?.cancel();
      controller.close();
    });

    return controller.stream;
  },
);
