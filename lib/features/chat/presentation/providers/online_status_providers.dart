import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Online status - stub for now (would need WebSocket for real-time)
/// Always returns false since we don't have real-time presence yet
final onlineStatusStreamProvider = StreamProvider.family<bool, String>(
  (ref, userId) async* {
    yield false;
  },
);

// Typing status - stub for now
final typingStatusStreamProvider = StreamProvider.family<Map<String, bool>, String>(
  (ref, chatId) async* {
    yield <String, bool>{};
  },
);
