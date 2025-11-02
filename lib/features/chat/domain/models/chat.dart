class Chat {
  final String id;
  final String userId;
  final String userName;
  final String userImageUrl;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final bool isOnline;

  Chat({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userImageUrl,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.isOnline = false,
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

