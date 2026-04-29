class Chat {
  final String id;
  final String userId;
  final String userName;
  final String userImageUrl;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final bool isOnline;
  final String? carId;
  final String? carName;
  final bool isPartner;

  Chat({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userImageUrl,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.isOnline = false,
    this.carId,
    this.carName,
    this.isPartner = false,
  });
}

class ChatMessage {
  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final String senderImageUrl;
  /// For text messages this is the body. For voice/image, the CDN URL once
  /// uploaded. While an upload is in flight (status == sending and a
  /// `localPath` is set) UI should prefer playing/rendering [localPath].
  final String message;
  final DateTime timestamp;
  final MessageType type;
  final bool isRead;
  final ReplyInfo? replyTo;
  final MessageStatus status;
  /// Client-generated UUID for idempotency / optimistic dedupe. The server
  /// echoes it back on the confirmed message so we can match the optimistic
  /// row to the server row exactly, instead of relying on a content+time
  /// heuristic. Null on legacy/server-loaded messages.
  final String? clientId;
  /// Local file path for media still uploading. Lets the sender play their
  /// own voice note / view their image immediately, before the upload
  /// finishes. Cleared once the server URL is in [message].
  final String? localPath;

  ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.senderImageUrl,
    required this.message,
    required this.timestamp,
    this.type = MessageType.text,
    this.isRead = false,
    this.replyTo,
    this.status = MessageStatus.sent,
    this.clientId,
    this.localPath,
  });

  ChatMessage copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? senderName,
    String? senderImageUrl,
    String? message,
    DateTime? timestamp,
    MessageType? type,
    bool? isRead,
    ReplyInfo? replyTo,
    MessageStatus? status,
    String? clientId,
    String? localPath,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderImageUrl: senderImageUrl ?? this.senderImageUrl,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      replyTo: replyTo ?? this.replyTo,
      status: status ?? this.status,
      clientId: clientId ?? this.clientId,
      localPath: localPath ?? this.localPath,
    );
  }
}


/// Local-only delivery state for an outgoing message, used to drive the
/// pending/sent/failed indicator in the chat UI. The server has no notion
/// of these — they exist only on the sender's device.
///
/// `uploading` is for media (voice, image): the file is being uploaded to
/// CDN. `sending` is the brief window after upload completes and we hit
/// the `/messages` API. UI typically renders both as a clock icon.
enum MessageStatus {
  uploading,
  sending,
  sent,
  failed,
}

class ReplyInfo {
  final String messageId;
  final String senderId;
  final String senderName;
  final String message;
  final MessageType type;

  ReplyInfo({
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.message,
    this.type = MessageType.text,
  });
}

enum MessageType {
  text,
  voice,
  image,
}

class Story {
  final String id;
  final String userId;
  final String userName;
  final String userImageUrl;
  final String? storyImageUrl;
  final bool isAddStory;

  Story({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userImageUrl,
    this.storyImageUrl,
    this.isAddStory = false,
  });
}

