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
  final String message;
  final DateTime timestamp;
  final MessageType type;
  final bool isRead;
  final ReplyInfo? replyTo;
  final MessageStatus status;

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
    );
  }
}

/// Local-only delivery state for an outgoing message, used to drive the
/// pending/sent/failed indicator in the chat UI. The server has no notion
/// of these — they exist only on the sender's device.
enum MessageStatus {
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

