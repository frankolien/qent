import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/core/services/websocket_service.dart';

/// Online status — derived from WebSocket connection state.
/// A user is considered "online" if the WS service is connected
/// (since the backend tracks connected sessions in WsManager).
/// For the *other* user, we'd need a presence protocol. For now,
/// we check the WS state for the current user and always show
/// online when WS is connected (since both users connect to WS).
final onlineStatusStreamProvider = StreamProvider.family<bool, String>(
  (ref, userId) {
    final ws = ref.watch(wsServiceProvider);
    // The WS manager on the backend tracks who's connected.
    // We return true if OUR websocket is connected (basic presence).
    // A proper implementation would have the backend broadcast
    // presence events, but for now this is a reasonable indicator.
    final controller = StreamController<bool>();

    // Check immediately
    controller.add(ws.state == WsState.connected);

    // Poll every 5 seconds
    final timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!controller.isClosed) {
        controller.add(ws.state == WsState.connected);
      }
    });

    ref.onDispose(() {
      timer.cancel();
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
