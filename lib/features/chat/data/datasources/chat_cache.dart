import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:qent/features/chat/domain/models/chat.dart';
import 'package:sqflite/sqflite.dart';

/// On-disk cache for chat messages and conversation list.
///
/// This is what makes chats "appear instantly" on app launch and on
/// re-entry: we read from sqflite first, render, *then* hit the network
/// in the background and reconcile. Same pattern Instagram, WhatsApp,
/// Telegram use.
///
/// Schema design notes:
///   - Messages keyed by their server `id`. We `INSERT OR REPLACE` on
///     write, so re-fetching the same conversation overwrites stale
///     entries (e.g. is_read flips). The compound index on
///     (conversation_id, created_at) keeps the per-chat read fast.
///   - Conversations keyed by server `id` too. Per-user fields like
///     `unread_count` are stored as a single number rather than the
///     server's renter/host split — we already have the role context
///     when we write.
///   - Reply preview is stored alongside the message rather than via a
///     join, since reads are always per-conversation and a denormalised
///     row is one table scan instead of two.
class ChatCache {
  ChatCache._();
  static final ChatCache instance = ChatCache._();

  static const _dbName = 'qent_chat_cache.db';
  static const _dbVersion = 1;

  Database? _db;
  Future<Database>? _opening;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    if (_opening != null) return _opening!;

    final completer = Completer<Database>();
    _opening = completer.future;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final path = p.join(dir.path, _dbName);
      final db = await openDatabase(
        path,
        version: _dbVersion,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE messages (
              id TEXT PRIMARY KEY,
              conversation_id TEXT NOT NULL,
              sender_id TEXT NOT NULL,
              sender_name TEXT NOT NULL,
              content TEXT NOT NULL,
              message_type TEXT NOT NULL,
              created_at INTEGER NOT NULL,
              is_read INTEGER NOT NULL DEFAULT 0,
              client_id TEXT,
              reply_to_id TEXT,
              reply_to_content TEXT,
              reply_to_sender_id TEXT,
              reply_to_sender_name TEXT,
              reply_to_message_type TEXT
            )
          ''');
          await db.execute(
            'CREATE INDEX idx_messages_convo_time '
            'ON messages(conversation_id, created_at)',
          );
          await db.execute('''
            CREATE TABLE conversations (
              id TEXT PRIMARY KEY,
              other_user_id TEXT NOT NULL,
              other_user_name TEXT NOT NULL,
              other_user_image_url TEXT NOT NULL DEFAULT '',
              last_message TEXT NOT NULL DEFAULT '',
              last_message_at INTEGER NOT NULL,
              unread_count INTEGER NOT NULL DEFAULT 0,
              car_id TEXT,
              car_name TEXT,
              is_partner INTEGER NOT NULL DEFAULT 0,
              cached_at INTEGER NOT NULL
            )
          ''');
          await db.execute(
            'CREATE INDEX idx_conversations_recent '
            'ON conversations(last_message_at DESC)',
          );
          // Outbox: optimistic sends that haven't been confirmed by the
          // server yet. Persisted so a force-close in the ~100-500ms
          // window between "user tapped send" and "server echo arrived"
          // doesn't drop the message. On chat re-open we hydrate this
          // back into pendingMessagesProvider and re-fire the HTTP send
          // (server dedupes via client_id).
          await db.execute('''
            CREATE TABLE pending_messages (
              id TEXT PRIMARY KEY,
              conversation_id TEXT NOT NULL,
              client_id TEXT NOT NULL,
              sender_id TEXT NOT NULL,
              sender_name TEXT NOT NULL,
              content TEXT NOT NULL,
              message_type TEXT NOT NULL,
              created_at INTEGER NOT NULL,
              status TEXT NOT NULL,
              local_path TEXT,
              reply_to_id TEXT,
              reply_to_content TEXT,
              reply_to_sender_id TEXT,
              reply_to_sender_name TEXT,
              reply_to_message_type TEXT
            )
          ''');
          await db.execute(
            'CREATE INDEX idx_pending_convo '
            'ON pending_messages(conversation_id, created_at)',
          );
        },
      );
      _db = db;
      completer.complete(db);
      return db;
    } catch (e, st) {
      completer.completeError(e, st);
      _opening = null;
      rethrow;
    } finally {
      _opening = null;
    }
  }

  // ---------------------------------------------------------------------------
  // Messages
  // ---------------------------------------------------------------------------

  Future<List<ChatMessage>> getMessages(String conversationId) async {
    try {
      final db = await _open();
      final rows = await db.query(
        'messages',
        where: 'conversation_id = ?',
        whereArgs: [conversationId],
        orderBy: 'created_at ASC',
      );
      return rows.map(_messageFromRow).toList();
    } catch (e) {
      debugPrint('[ChatCache] getMessages failed: $e');
      return const [];
    }
  }

  /// Replace the cached messages for a conversation with the given list.
  /// Used after a successful REST refetch — server is canonical, so we
  /// overwrite local state to drop any deleted messages.
  Future<void> replaceMessages(
      String conversationId, List<ChatMessage> messages) async {
    try {
      final db = await _open();
      await db.transaction((txn) async {
        await txn.delete(
          'messages',
          where: 'conversation_id = ?',
          whereArgs: [conversationId],
        );
        final batch = txn.batch();
        for (final m in messages) {
          batch.insert(
            'messages',
            _messageToRow(m, conversationId),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      });
    } catch (e) {
      debugPrint('[ChatCache] replaceMessages failed: $e');
    }
  }

  /// Insert or update a single message — used by the WebSocket arrival
  /// path and the optimistic send → confirm path. Idempotent via primary
  /// key (the message id), so it's safe to call repeatedly with the same
  /// row.
  Future<void> upsertMessage(ChatMessage message) async {
    try {
      final db = await _open();
      await db.insert(
        'messages',
        _messageToRow(message, message.chatId),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('[ChatCache] upsertMessage failed: $e');
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      final db = await _open();
      await db.delete('messages', where: 'id = ?', whereArgs: [messageId]);
    } catch (e) {
      debugPrint('[ChatCache] deleteMessage failed: $e');
    }
  }

  Future<void> clearConversationMessages(String conversationId) async {
    try {
      final db = await _open();
      await db.delete(
        'messages',
        where: 'conversation_id = ?',
        whereArgs: [conversationId],
      );
    } catch (e) {
      debugPrint('[ChatCache] clearConversationMessages failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Conversations
  // ---------------------------------------------------------------------------

  Future<List<Chat>> getConversations() async {
    try {
      final db = await _open();
      final rows = await db.query(
        'conversations',
        orderBy: 'last_message_at DESC',
      );
      return rows.map(_chatFromRow).toList();
    } catch (e) {
      debugPrint('[ChatCache] getConversations failed: $e');
      return const [];
    }
  }

  Future<void> replaceConversations(List<Chat> chats) async {
    try {
      final db = await _open();
      await db.transaction((txn) async {
        await txn.delete('conversations');
        final now = DateTime.now().millisecondsSinceEpoch;
        final batch = txn.batch();
        for (final c in chats) {
          batch.insert(
            'conversations',
            _chatToRow(c, now),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      });
    } catch (e) {
      debugPrint('[ChatCache] replaceConversations failed: $e');
    }
  }

  Future<void> upsertConversation(Chat chat) async {
    try {
      final db = await _open();
      await db.insert(
        'conversations',
        _chatToRow(chat, DateTime.now().millisecondsSinceEpoch),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('[ChatCache] upsertConversation failed: $e');
    }
  }

  /// Bump a conversation's last-message preview + timestamp in place.
   /// Used when a new_message arrives over WebSocket so the chats list
   /// re-emits in the correct order even before the next REST refetch
   /// lands. If the conversation row doesn't exist (first message in a
   /// brand-new convo) this is a no-op — REST will pick it up.
  Future<void> bumpConversation({
    required String conversationId,
    required String lastMessageText,
    required DateTime lastMessageAt,
    int? unreadDelta,
  }) async {
    try {
      final db = await _open();
      final values = <String, Object?>{
        'last_message': lastMessageText,
        'last_message_at': lastMessageAt.millisecondsSinceEpoch,
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      };
      await db.update(
        'conversations',
        values,
        where: 'id = ?',
        whereArgs: [conversationId],
      );
      if (unreadDelta != null && unreadDelta > 0) {
        await db.rawUpdate(
          'UPDATE conversations SET unread_count = unread_count + ? WHERE id = ?',
          [unreadDelta, conversationId],
        );
      }
    } catch (e) {
      debugPrint('[ChatCache] bumpConversation failed: $e');
    }
  }

  /// Reset the cached unread count for a conversation to zero. Called
  /// when the user opens the chat (mirrors the server's mark_read), so
  /// the chats list's blue badge clears instantly without waiting on
  /// the next REST refetch.
  Future<void> clearUnread(String conversationId) async {
    try {
      final db = await _open();
      await db.update(
        'conversations',
        const {'unread_count': 0},
        where: 'id = ?',
        whereArgs: [conversationId],
      );
    } catch (e) {
      debugPrint('[ChatCache] clearUnread failed: $e');
    }
  }

  Future<void> deleteConversation(String conversationId) async {
    try {
      final db = await _open();
      await db.transaction((txn) async {
        await txn.delete(
          'conversations',
          where: 'id = ?',
          whereArgs: [conversationId],
        );
        await txn.delete(
          'messages',
          where: 'conversation_id = ?',
          whereArgs: [conversationId],
        );
      });
    } catch (e) {
      debugPrint('[ChatCache] deleteConversation failed: $e');
    }
  }

  /// Wipe the whole cache. Call on logout — the next user shouldn't
  /// see the previous user's chats.
  Future<void> clearAll() async {
    try {
      final db = await _open();
      await db.transaction((txn) async {
        await txn.delete('messages');
        await txn.delete('conversations');
        await txn.delete('pending_messages');
      });
    } catch (e) {
      debugPrint('[ChatCache] clearAll failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Outbox (pending optimistic sends)
  // ---------------------------------------------------------------------------

  Future<List<ChatMessage>> getPendingMessages(String conversationId) async {
    try {
      final db = await _open();
      final rows = await db.query(
        'pending_messages',
        where: 'conversation_id = ?',
        whereArgs: [conversationId],
        orderBy: 'created_at ASC',
      );
      return rows.map(_pendingFromRow).toList();
    } catch (e) {
      debugPrint('[ChatCache] getPendingMessages failed: $e');
      return const [];
    }
  }

  Future<List<ChatMessage>> getAllPendingMessages() async {
    try {
      final db = await _open();
      final rows = await db.query(
        'pending_messages',
        orderBy: 'created_at ASC',
      );
      return rows.map(_pendingFromRow).toList();
    } catch (e) {
      debugPrint('[ChatCache] getAllPendingMessages failed: $e');
      return const [];
    }
  }

  Future<void> upsertPendingMessage(ChatMessage m) async {
    try {
      final db = await _open();
      await db.insert(
        'pending_messages',
        _pendingToRow(m),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('[ChatCache] upsertPendingMessage failed: $e');
    }
  }

  Future<void> deletePendingMessage(String tempId) async {
    try {
      final db = await _open();
      await db.delete(
        'pending_messages',
        where: 'id = ?',
        whereArgs: [tempId],
      );
    } catch (e) {
      debugPrint('[ChatCache] deletePendingMessage failed: $e');
    }
  }

  Future<void> deletePendingByClientId(String clientId) async {
    try {
      final db = await _open();
      await db.delete(
        'pending_messages',
        where: 'client_id = ?',
        whereArgs: [clientId],
      );
    } catch (e) {
      debugPrint('[ChatCache] deletePendingByClientId failed: $e');
    }
  }

  Map<String, dynamic> _pendingToRow(ChatMessage m) {
    return {
      'id': m.id,
      'conversation_id': m.chatId,
      'client_id': m.clientId ?? '',
      'sender_id': m.senderId,
      'sender_name': m.senderName,
      'content': m.message,
      'message_type': m.type.name,
      'created_at': m.timestamp.toUtc().millisecondsSinceEpoch,
      'status': m.status.name,
      'local_path': m.localPath,
      'reply_to_id': m.replyTo?.messageId,
      'reply_to_content': m.replyTo?.message,
      'reply_to_sender_id': m.replyTo?.senderId,
      'reply_to_sender_name': m.replyTo?.senderName,
      'reply_to_message_type': m.replyTo?.type.name,
    };
  }

  ChatMessage _pendingFromRow(Map<String, Object?> row) {
    final replyToId = row['reply_to_id'] as String?;
    final replyToContent = row['reply_to_content'] as String?;
    ReplyInfo? replyTo;
    if (replyToId != null && replyToContent != null) {
      replyTo = ReplyInfo(
        messageId: replyToId,
        senderId: (row['reply_to_sender_id'] as String?) ?? '',
        senderName: (row['reply_to_sender_name'] as String?) ?? '',
        message: replyToContent,
        type: _parseType(row['reply_to_message_type'] as String?),
      );
    }
    final cid = (row['client_id'] as String?) ?? '';
    return ChatMessage(
      id: row['id'] as String,
      chatId: row['conversation_id'] as String,
      senderId: row['sender_id'] as String,
      senderName: row['sender_name'] as String,
      senderImageUrl: '',
      message: row['content'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        row['created_at'] as int,
        isUtc: true,
      ).toLocal(),
      type: _parseType(row['message_type'] as String?),
      isRead: false,
      replyTo: replyTo,
      status: _parseStatus(row['status'] as String?),
      clientId: cid.isEmpty ? null : cid,
      localPath: row['local_path'] as String?,
    );
  }

  MessageStatus _parseStatus(String? raw) {
    switch (raw) {
      case 'uploading':
        return MessageStatus.uploading;
      case 'failed':
        return MessageStatus.failed;
      case 'sent':
        return MessageStatus.sent;
      default:
        return MessageStatus.sending;
    }
  }

  // ---------------------------------------------------------------------------
  // Row mapping
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _messageToRow(ChatMessage m, String conversationId) {
    return {
      'id': m.id,
      'conversation_id': conversationId,
      'sender_id': m.senderId,
      'sender_name': m.senderName,
      'content': m.message,
      'message_type': m.type.name,
      'created_at': m.timestamp.toUtc().millisecondsSinceEpoch,
      'is_read': m.isRead ? 1 : 0,
      'client_id': m.clientId,
      'reply_to_id': m.replyTo?.messageId,
      'reply_to_content': m.replyTo?.message,
      'reply_to_sender_id': m.replyTo?.senderId,
      'reply_to_sender_name': m.replyTo?.senderName,
      'reply_to_message_type': m.replyTo?.type.name,
    };
  }

  ChatMessage _messageFromRow(Map<String, Object?> row) {
    final replyToId = row['reply_to_id'] as String?;
    final replyToContent = row['reply_to_content'] as String?;
    ReplyInfo? replyTo;
    if (replyToId != null && replyToContent != null) {
      replyTo = ReplyInfo(
        messageId: replyToId,
        senderId: (row['reply_to_sender_id'] as String?) ?? '',
        senderName: (row['reply_to_sender_name'] as String?) ?? '',
        message: replyToContent,
        type: _parseType(row['reply_to_message_type'] as String?),
      );
    }
    final tsMillis = row['created_at'] as int;
    return ChatMessage(
      id: row['id'] as String,
      chatId: row['conversation_id'] as String,
      senderId: row['sender_id'] as String,
      senderName: row['sender_name'] as String,
      senderImageUrl: '',
      message: row['content'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(tsMillis, isUtc: true)
          .toLocal(),
      type: _parseType(row['message_type'] as String?),
      isRead: (row['is_read'] as int? ?? 0) != 0,
      replyTo: replyTo,
      clientId: row['client_id'] as String?,
    );
  }

  Map<String, dynamic> _chatToRow(Chat c, int cachedAtMillis) {
    return {
      'id': c.id,
      'other_user_id': c.userId,
      'other_user_name': c.userName,
      'other_user_image_url': c.userImageUrl,
      'last_message': c.lastMessage,
      'last_message_at': c.lastMessageTime.toUtc().millisecondsSinceEpoch,
      'unread_count': c.unreadCount,
      'car_id': c.carId,
      'car_name': c.carName,
      'is_partner': c.isPartner ? 1 : 0,
      'cached_at': cachedAtMillis,
    };
  }

  Chat _chatFromRow(Map<String, Object?> row) {
    return Chat(
      id: row['id'] as String,
      userId: row['other_user_id'] as String,
      userName: row['other_user_name'] as String,
      userImageUrl: (row['other_user_image_url'] as String?) ?? '',
      lastMessage: (row['last_message'] as String?) ?? '',
      lastMessageTime: DateTime.fromMillisecondsSinceEpoch(
        row['last_message_at'] as int,
        isUtc: true,
      ).toLocal(),
      unreadCount: (row['unread_count'] as int?) ?? 0,
      carId: row['car_id'] as String?,
      carName: row['car_name'] as String?,
      isPartner: (row['is_partner'] as int? ?? 0) != 0,
    );
  }

  MessageType _parseType(String? raw) {
    switch (raw) {
      case 'voice':
        return MessageType.voice;
      case 'image':
        return MessageType.image;
      default:
        return MessageType.text;
    }
  }
}

final chatCacheProvider = Provider<ChatCache>((ref) => ChatCache.instance);
