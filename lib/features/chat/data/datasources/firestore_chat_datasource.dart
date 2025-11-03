import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:qent/features/chat/domain/models/chat.dart';
import 'package:qent/features/chat/data/datasources/fcm_notification_datasource.dart';

class FirestoreChatDataSource {
  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;
  final FCMNotificationDataSource? _notificationDataSource;

  FirestoreChatDataSource({
    required FirebaseFirestore firestore,
    required fb.FirebaseAuth auth,
    FCMNotificationDataSource? notificationDataSource,
  })  : _firestore = firestore,
        _auth = auth,
        _notificationDataSource = notificationDataSource;

  String get _currentUserId => _auth.currentUser?.uid ?? '';

  // Stream of all chats for current user
  Stream<List<Chat>> getChatsStream() {
    if (_currentUserId.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: _currentUserId)
        .snapshots()
        .asyncMap((snapshot) async {
      final chats = <Chat>[];
      final userIdsToFetch = <String>{};
      final chatsWithUserIds = <Chat, String>{};
      
      // First pass: extract user IDs and use cached/stored data
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          final participants = List<String>.from(data['participants'] ?? []);
          final otherUserId = participants.firstWhere(
            (id) => id != _currentUserId,
            orElse: () => participants.isNotEmpty ? participants.first : '',
          );
          
          if (otherUserId.isNotEmpty) {
            userIdsToFetch.add(otherUserId);
          }
          
          // Create chat with stored data first (fast)
          final chat = Chat(
            id: doc.id,
            userId: otherUserId,
            userName: data['userName'] ?? 'Unknown',
            userImageUrl: data['userImageUrl'] ?? '',
            lastMessage: data['lastMessage'] ?? '',
            lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
            unreadCount: data['unreadCount'] ?? 0,
            isOnline: false, // Will update from cache if available
          );
          
          chats.add(chat);
          if (otherUserId.isNotEmpty) {
            chatsWithUserIds[chat] = otherUserId;
          }
        } catch (e) {
          debugPrint('Error loading chat ${doc.id}: $e');
        }
      }
      
      // Batch fetch user data only if needed (optimize: only fetch if data is stale)
      if (userIdsToFetch.isNotEmpty) {
        try {
          final userDocs = await Future.wait(
            userIdsToFetch.map((id) => _firestore.collection('users').doc(id).get()),
          );
          
          final userDataMap = <String, Map<String, dynamic>>{};
          for (var i = 0; i < userIdsToFetch.length; i++) {
            final userId = userIdsToFetch.elementAt(i);
            final userDoc = userDocs[i];
            if (userDoc.exists) {
              userDataMap[userId] = userDoc.data() ?? {};
            }
          }
          
          // Update chats with fresh user data
          for (var i = 0; i < chats.length; i++) {
            final chat = chats[i];
            final userId = chatsWithUserIds[chat];
            if (userId != null) {
              final userData = userDataMap[userId];
              if (userData != null) {
                final userName = userData['fullName'] ?? chat.userName;
                final userImageUrl = userData['profileImageUrl'] ?? chat.userImageUrl;
                final onlineValue = userData['isOnline'];
                final isOnline = onlineValue is bool ? onlineValue : (onlineValue == true);
                
                // Create new chat instance with updated data
                chats[i] = Chat(
                  id: chat.id,
                  userId: chat.userId,
                  userName: userName,
                  userImageUrl: userImageUrl,
                  lastMessage: chat.lastMessage,
                  lastMessageTime: chat.lastMessageTime,
                  unreadCount: chat.unreadCount,
                  isOnline: isOnline,
                );
              }
            }
          }
        } catch (e) {
          debugPrint('Error batch fetching user data: $e');
          // Continue with stored data on error
        }
      }
      
      // Sort by lastMessageTime in memory
      chats.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
      
      return chats;
    });
  }

  // Stream of messages for a specific chat
  Stream<List<ChatMessage>> getMessagesStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => _messageFromFirestore(doc))
          .toList();
    });
  }

  // Set typing status
  Future<void> setTypingStatus(String chatId, bool isTyping) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('typing')
          .doc(_currentUserId)
          .set({
        'isTyping': isTyping,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error setting typing status: $e');
    }
  }

  // Get typing status stream
  Stream<Map<String, bool>> getTypingStatusStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('typing')
        .snapshots()
        .map((snapshot) {
      final typingStatus = <String, bool>{};
      for (var doc in snapshot.docs) {
        if (doc.id != _currentUserId) {
          final data = doc.data();
          final isTyping = data['isTyping'] ?? false;
          final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
          if (timestamp != null) {
            final now = DateTime.now();
            final difference = now.difference(timestamp);
            if (difference.inSeconds < 3 && isTyping) {
              typingStatus[doc.id] = true;
            }
          }
        }
      }
      return typingStatus;
    });
  }

  // Send a message
  Future<void> sendMessage({
    required String chatId,
    required String message,
    required MessageType type,
    String? replyToMessageId,
    ReplyInfo? replyTo,
  }) async {
    final messageRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc();

    final chatRef = _firestore.collection('chats').doc(chatId);

    final batch = _firestore.batch();

    // Prepare message data
    final messageData = {
      'id': messageRef.id,
      'chatId': chatId,
      'senderId': _currentUserId,
      'senderName': _auth.currentUser?.displayName ?? 'You',
      'senderImageUrl': _auth.currentUser?.photoURL ?? '',
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'type': type.name,
      'isRead': false,
    };

    if (replyToMessageId != null && replyTo != null) {
      messageData['replyToMessageId'] = replyToMessageId;
      messageData['replyTo'] = {
        'messageId': replyTo.messageId,
        'senderId': replyTo.senderId,
        'senderName': replyTo.senderName,
        'message': replyTo.message,
        'type': replyTo.type.name,
      };
    }

    // Add message
    batch.set(messageRef, messageData);

    // Update chat last message
    batch.update(chatRef, {
      'lastMessage': type == MessageType.voice ? 'Voice message' : message,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': _currentUserId,
    });

    await batch.commit();

    // Send push notification to the other participant
    if (_notificationDataSource != null) {
      try {
        final chatDoc = await chatRef.get();
        final chatData = chatDoc.data() ?? {};
        final participants = List<String>.from(chatData['participants'] ?? []);
        final otherUserId = participants.firstWhere(
          (id) => id != _currentUserId,
          orElse: () => '',
        );

        if (otherUserId.isNotEmpty) {
          final senderName = _auth.currentUser?.displayName ?? 
              _auth.currentUser?.email?.split('@').first ?? 
              'Someone';
          
          await _notificationDataSource.sendNotificationToUser(
            userId: otherUserId,
            title: senderName,
            body: type == MessageType.voice ? 'Sent a voice message' : message,
            data: {
              'chatId': chatId,
              'senderId': _currentUserId,
              'messageType': type.name,
            },
          );
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error sending notification: $e');
        }
        // Don't fail the message send if notification fails
      }
    }
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String chatId) async {
    final unreadMessages = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('senderId', isNotEqualTo: _currentUserId)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (var doc in unreadMessages.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();

    // Update unread count
    final unreadCount = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('senderId', isNotEqualTo: _currentUserId)
        .where('isRead', isEqualTo: false)
        .get();

    await _firestore.collection('chats').doc(chatId).update({
      'unreadCount': unreadCount.docs.length,
    });
  }

  // Create or get chat
  Future<String> createOrGetChat(String otherUserId) async {
    // Check if chat already exists
    final existingChats = await _firestore
        .collection('chats')
        .where('participants', arrayContains: _currentUserId)
        .get();

    for (var doc in existingChats.docs) {
      final data = doc.data();
      final participants = List<String>.from(data['participants'] ?? []);
      if (participants.contains(otherUserId) &&
          participants.contains(_currentUserId) &&
          participants.length == 2) {
        return doc.id;
      }
    }

    // Get other user's profile data
    final otherUserDoc = await _firestore.collection('users').doc(otherUserId).get();
    final otherUserData = otherUserDoc.exists ? (otherUserDoc.data() ?? {}) : {};

    // Create new chat
    final chatRef = _firestore.collection('chats').doc();
    await chatRef.set({
      'id': chatRef.id,
      'participants': [_currentUserId, otherUserId],
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'userName': otherUserData['fullName'] ?? 'Unknown',
      'userImageUrl': otherUserData['profileImageUrl'] ?? '',
      'isOnline': false,
      'unreadCount': 0,
    });

    return chatRef.id;
  }

  // Get user data
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      debugPrint('Error getting user data: $e');
      return null;
    }
  }

  // Search for users by name or email
  Stream<List<Map<String, dynamic>>> searchUsers(String query) {
    if (query.isEmpty) {
      return Stream.value([]);
    }

    final queryLower = query.toLowerCase();
    return _firestore
        .collection('users')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .where((doc) {
            // Exclude current user
            if (doc.id == _currentUserId) return false;
            final data = doc.data();
            final name = (data['fullName'] ?? '').toString().toLowerCase();
            final email = (data['email'] ?? '').toString().toLowerCase();
            return name.contains(queryLower) || email.contains(queryLower);
          })
          .map((doc) {
            final data = doc.data();
            return {
              'uid': doc.id,
              'fullName': data['fullName'] ?? 'Unknown',
              'email': data['email'] ?? '',
              'country': data['country'] ?? '',
            };
          })
          .toList();
    });
  }

  // Get all users (excluding current user)
  Stream<List<Map<String, dynamic>>> getAllUsers() {
    return _firestore
        .collection('users')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .where((doc) => doc.id != _currentUserId)
          .map((doc) {
            final data = doc.data();
            return {
              'uid': doc.id,
              'fullName': data['fullName'] ?? 'Unknown',
              'email': data['email'] ?? '',
              'country': data['country'] ?? '',
            };
          })
          .toList();
    });
  }

  // Delete a message
  Future<void> deleteMessage(String chatId, String messageId) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting message: $e');
      rethrow;
    }
  }

  // Forward a message to another chat
  Future<void> forwardMessage({
    required String fromChatId,
    required String toChatId,
    required ChatMessage message,
  }) async {
    try {
      await sendMessage(
        chatId: toChatId,
        message: message.message,
        type: message.type,
      );
    } catch (e) {
      debugPrint('Error forwarding message: $e');
      rethrow;
    }
  }

  ChatMessage _messageFromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    ReplyInfo? replyTo;
    if (data['replyTo'] != null) {
      final replyData = data['replyTo'] as Map<String, dynamic>;
      replyTo = ReplyInfo(
        messageId: replyData['messageId'] ?? '',
        senderId: replyData['senderId'] ?? '',
        senderName: replyData['senderName'] ?? 'Unknown',
        message: replyData['message'] ?? '',
        type: MessageType.values.firstWhere(
          (e) => e.name == (replyData['type'] ?? 'text'),
          orElse: () => MessageType.text,
        ),
      );
    }
    
    return ChatMessage(
      id: doc.id,
      chatId: data['chatId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'Unknown',
      senderImageUrl: data['senderImageUrl'] ?? '',
      message: data['message'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: MessageType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => MessageType.text,
      ),
      isRead: data['isRead'] ?? false,
      replyTo: replyTo,
    );
  }
}

