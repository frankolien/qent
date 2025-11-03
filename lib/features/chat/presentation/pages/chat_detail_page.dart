import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qent/core/widgets/profile_image_widget.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart' as auth_providers;
import 'package:qent/features/chat/domain/models/chat.dart';
import 'package:qent/features/chat/presentation/controllers/chat_controller.dart';
import 'package:qent/features/chat/presentation/providers/online_status_providers.dart';
import 'package:qent/features/chat/presentation/pages/new_chat_page.dart';
import 'package:qent/features/chat/presentation/widgets/chat_skeleton.dart';
import 'dart:async';

class ChatDetailPage extends ConsumerStatefulWidget {
  final Chat chat;

  const ChatDetailPage({
    super.key,
    required this.chat,
  });

  @override
  ConsumerState<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends ConsumerState<ChatDetailPage> with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _hasMarkedAsRead = false;
  bool _showAttachmentOptions = false;
  ReplyInfo? _replyingTo;
  Timer? _typingTimer;
  bool _isUserTyping = false;
  late AnimationController _typingAnimationController;
  ChatController? _chatController;
  
  @override
  void initState() {
    super.initState();
    _typingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    
    _messageController.addListener(_onMessageChanged);
    _focusNode.addListener(_onFocusChanged);
    
    // Listen to typing status and update local state
    _updateTypingStatus();
  }
  
  void _onMessageChanged() {
    setState(() {
      // Trigger rebuild for input field
    });
    
    if (_chatController == null) {
      _chatController = ref.read(chatControllerProvider);
    }
    final chatController = _chatController!;
    
    // Update typing status in Firestore
    if (_messageController.text.trim().isNotEmpty && !_isUserTyping) {
      _isUserTyping = true;
      chatController.setTypingStatus(widget.chat.id, true);
    } else if (_messageController.text.trim().isEmpty && _isUserTyping) {
      _isUserTyping = false;
      chatController.setTypingStatus(widget.chat.id, false);
    }
    
    // Reset typing timer
    _typingTimer?.cancel();
    if (_messageController.text.trim().isNotEmpty) {
      _typingTimer = Timer(const Duration(seconds: 2), () {
        if (mounted && _isUserTyping && _chatController != null) {
          _isUserTyping = false;
          _chatController!.setTypingStatus(widget.chat.id, false);
        }
      });
    }
  }
  
  void _onFocusChanged() {
    // Don't auto-hide attachment options when focus changes
    // User can toggle it manually
  }
  
  void _updateTypingStatus() {
    // This will be handled by watching the typingStatusStreamProvider in build
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _messageController.removeListener(_onMessageChanged);
    _focusNode.removeListener(_onFocusChanged);
    
    // Use stored controller reference to avoid unsafe ref usage during dispose
    if (_chatController != null && mounted) {
      try {
        _chatController!.setTypingStatus(widget.chat.id, false);
      } catch (e) {
        // Ignore errors during dispose
      }
    }
    
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _typingAnimationController.dispose();
    super.dispose();
  }

  String _formatMessageTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'pm' : 'am';
    return '$hour:$minute $period';
  }
  
  String _formatDate(DateTime date) {
    return DateFormat('EEEE, MMMM d').format(date);
  }
  
  bool _shouldShowDateSeparator(List<ChatMessage> messages, int index) {
    if (index == 0) return true;
    
    final currentDate = DateTime(
      messages[index].timestamp.year,
      messages[index].timestamp.month,
      messages[index].timestamp.day,
    );
    final previousDate = DateTime(
      messages[index - 1].timestamp.year,
      messages[index - 1].timestamp.month,
      messages[index - 1].timestamp.day,
    );
    
    return currentDate != previousDate;
  }
  
  void _showMessageMenu(BuildContext context, ChatMessage message) {
    HapticFeedback.mediumImpact();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMenuOption(
                context,
                icon: Icons.copy,
                label: 'Copy',
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message.message));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message copied')),
                  );
                },
              ),
              _buildMenuOption(
                context,
                icon: Icons.reply,
                label: 'Reply',
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _replyingTo = ReplyInfo(
                      messageId: message.id,
                      senderId: message.senderId,
                      senderName: message.senderName,
                      message: message.message,
                      type: message.type,
                    );
                  });
                  _focusNode.requestFocus();
                },
              ),
              _buildMenuOption(
                context,
                icon: Icons.forward,
                label: 'Forward',
                onTap: () {
                  Navigator.pop(context);
                  _showForwardDialog(context, message);
                },
              ),
              _buildMenuOption(
                context,
                icon: Icons.delete_outline,
                label: 'Delete',
                isDestructive: true,
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(context, message);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildMenuOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? Colors.red : Colors.black87,
              size: 24,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: isDestructive ? Colors.red : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showDeleteConfirmation(BuildContext context, ChatMessage message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(chatControllerProvider).deleteMessage(
                  widget.chat.id,
                  message.id,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message deleted')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting message: $e')),
                  );
                }
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showForwardDialog(BuildContext context, ChatMessage message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forward Message'),
        content: const Text('Select a chat to forward this message to'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NewChatPage(isForwarding: true),
                ),
              ).then((selectedChat) {
                if (selectedChat != null && selectedChat is Chat) {
                  _forwardMessage(context, message, selectedChat);
                }
              });
            },
            child: const Text('Select Chat'),
          ),
        ],
      ),
    );
  }

  Future<void> _forwardMessage(BuildContext context, ChatMessage message, Chat targetChat) async {
    try {
      await ref.read(chatControllerProvider).forwardMessage(
        fromChatId: widget.chat.id,
        toChatId: targetChat.id,
        message: message,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message forwarded')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error forwarding message: $e')),
        );
      }
    }
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final message = _messageController.text.trim();
    final replyTo = _replyingTo;
    final replyToMessageId = _replyingTo?.messageId;
    
    _messageController.clear();
    setState(() {
      _replyingTo = null;
      _isUserTyping = false;
    });
    
    // Get chat controller
    if (_chatController == null) {
      _chatController = ref.read(chatControllerProvider);
    }
    final chatController = _chatController!;
    
    // Stop typing status
    chatController.setTypingStatus(widget.chat.id, false);
    
    HapticFeedback.lightImpact();

    chatController.sendMessage(
      chatId: widget.chat.id,
      message: message,
      type: MessageType.text,
      replyToMessageId: replyToMessageId,
      replyTo: replyTo,
    );

    // Auto-scroll to bottom with smooth animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Mark messages as read when opening chat (only once)
    if (!_hasMarkedAsRead) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(chatControllerProvider).markAsRead(widget.chat.id);
        _hasMarkedAsRead = true;
      });
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        
        title: Consumer(
          builder: (context, ref, child) {
            final onlineStatusAsync = ref.watch(onlineStatusStreamProvider(widget.chat.userId));
            final isOnline = onlineStatusAsync.value ?? false;
            
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ProfileImageWidget(
                      userId: widget.chat.userId,
                      size: 40,
                    ),
                    if (isOnline)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.chat.userName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize: 12,
                          color: isOnline ? Colors.green : Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.black),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.phone, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Partner Banner (dynamic)
          Consumer(
            builder: (context, ref, _) {
              final firestore = FirebaseFirestore.instance;
              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: firestore.collection('users').doc(widget.chat.userId).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox.shrink();
                  }
                  final doc = snapshot.data!;
                  if (!doc.exists) return const SizedBox.shrink();
                  final data = doc.data() ?? {};
                  final isPartner = (data['isPartner'] == true);
                  if (!isPartner) return const SizedBox.shrink();
                  final partnerName = (data['partnerDisplayName'] ?? data['fullName'] ?? widget.chat.userName).toString();

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: Colors.blue[50],
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                partnerName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$partnerName is a QENT Partner',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          // Messages List
          Expanded(
            child: _buildMessagesList(),
          ),
          // Message Input
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    final messagesAsync = ref.watch(messagesStreamProvider(widget.chat.id));

    return messagesAsync.when(
      data: (messages) {
        // Auto-scroll to bottom when new messages arrive
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients && messages.isNotEmpty) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        });

        if (messages.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No messages yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(messagesStreamProvider(widget.chat.id));
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: Consumer(
            builder: (context, ref, child) {
              final typingStatusAsync = ref.watch(typingStatusStreamProvider(widget.chat.id));
              final isOtherUserTyping = typingStatusAsync.value?.isNotEmpty ?? false;
              
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 16),
                itemCount: messages.length + (isOtherUserTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == messages.length) {
                    return _buildTypingIndicator();
                  }
                  
                  final message = messages[index];
                  final auth = ref.read(auth_providers.firebaseAuthProvider);
                  final currentUserId = auth.currentUser?.uid ?? '';
                  final isMe = message.senderId == currentUserId || message.senderId == 'current';
              
              // Check if we should show date separator
              final showDateSeparator = _shouldShowDateSeparator(messages, index);
              
              // Check if previous message is from same sender and within 5 minutes
              final showAvatar = index == 0 || 
                  messages[index - 1].senderId != message.senderId ||
                  message.timestamp.difference(messages[index - 1].timestamp).inMinutes > 5;
              
              return Column(
                children: [
                  if (showDateSeparator) _buildDateSeparator(message.timestamp),
                  GestureDetector(
                    onLongPress: () => _showMessageMenu(context, message),
                    child: _buildMessageBubble(
                      message,
                      showAvatar: showAvatar,
                      isMe: isMe,
                    ),
                  ),
                ],
              );
                },
              );
            },
          ),
        );
      },
      loading: () => const MessageListSkeleton(),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Error loading messages',
              style: TextStyle(color: Colors.red[600]),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                ref.invalidate(messagesStreamProvider(widget.chat.id));
                // Force rebuild by reading the provider
                ref.read(messagesStreamProvider(widget.chat.id));
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Center(
        child: Text(
          _formatDate(date),
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, {required bool showAvatar, required bool isMe}) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: showAvatar ? 8 : 2, // Less spacing between grouped messages
        bottom: 2,
      ),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            // Only show avatar if this is the first message in a group
            if (showAvatar) ...[
              ProfileImageWidget(
                userId: message.senderId,
                size: 32,
              ),
              const SizedBox(width: 8),
            ] else ...[
              // Spacer to align with messages that have avatars
              const SizedBox(width: 40),
            ],
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Reply indicator
                if (message.replyTo != null)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.arrow_back, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Replying to',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                message.replyTo!.message.length > 40
                                    ? '${message.replyTo!.message.substring(0, 40)}...'
                                    : message.replyTo!.message,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w400,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.black : Colors.grey[200],
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isMe ? 20 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: message.type == MessageType.voice
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.graphic_eq, color: isMe ? Colors.white : Colors.grey[700], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Voice message',
                              style: TextStyle(
                                fontSize: 14,
                                color: isMe ? Colors.white : Colors.grey[700],
                              ),
                            ),
                          ],
                        )
                      : Text(
                          message.message,
                          style: TextStyle(
                            fontSize: 14,
                            color: isMe ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w400,
                          ),
                          softWrap: true,
                        ),
                ),
                // Timestamp below each message
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatMessageTime(message.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                      if (isMe && message.isRead) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done_all,
                          size: 14,
                          color: Colors.blue[600],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          ProfileImageWidget(
            userId: widget.chat.userId,
            size: 32,
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(20),
            ),
            child: AnimatedBuilder(
              animation: _typingAnimationController,
              builder: (context, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildAnimatedDot(0),
                    const SizedBox(width: 4),
                    _buildAnimatedDot(0.3),
                    const SizedBox(width: 4),
                    _buildAnimatedDot(0.6),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAnimatedDot(double delay) {
    return AnimatedBuilder(
      animation: _typingAnimationController,
      builder: (context, child) {
        final value = (_typingAnimationController.value + delay) % 1.0;
        final opacity = value < 0.5 ? value * 2 : (1 - value) * 2;
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey[600]?.withOpacity(opacity),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildMessageInput() {
    final hasText = _messageController.text.trim().isNotEmpty;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Reply preview in input
        if (_replyingTo != null) _buildInputReplyPreview(),
        // Attachment options (shown when focused)
        if (_showAttachmentOptions) _buildAttachmentOptions(),
        Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom,
            top: 8,
            left: 16,
            right: 16,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Plus button (circular, light grey background)
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    _showAttachmentOptions ? Icons.close : Icons.add,
                    color: Colors.grey[700],
                    size: 20,
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _showAttachmentOptions = !_showAttachmentOptions;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 100),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: TextField(
                    controller: _messageController,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: 'Start a message',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    ),
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Microphone button or Send button
              if (hasText)
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[600],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                  onPressed: _sendMessage,
                )
              else
                IconButton(
                  icon: Icon(Icons.mic, color: Colors.grey[700], size: 24),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    // TODO: Implement voice recording
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildAttachmentOptions() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildAttachmentOption(
            icon: Icons.photo_library,
            label: 'Gallery',
            onTap: () {
              HapticFeedback.lightImpact();
              // TODO: Implement gallery picker
            },
          ),
          _buildAttachmentOption(
            icon: Icons.camera_alt,
            label: 'Camera',
            onTap: () {
              HapticFeedback.lightImpact();
              // TODO: Implement camera
            },
          ),
          _buildAttachmentOption(
            icon: Icons.attach_file,
            label: 'Document',
            onTap: () {
              HapticFeedback.lightImpact();
              // TODO: Implement document picker
            },
          ),
          _buildAttachmentOption(
            icon: Icons.mic,
            label: 'Voice',
            onTap: () {
              HapticFeedback.lightImpact();
              // TODO: Implement voice recording
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildInputReplyPreview() {
    final auth = ref.read(auth_providers.firebaseAuthProvider);
    final currentUserId = auth.currentUser?.uid ?? '';
    final isReplyFromMe = _replyingTo!.senderId == currentUserId;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border(
          left: BorderSide(
            color: isReplyFromMe ? Colors.blue : Colors.grey[600]!,
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to ${isReplyFromMe ? 'yourself' : _replyingTo!.senderName}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[700],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _replyingTo!.message.length > 60
                      ? '${_replyingTo!.message.substring(0, 60)}...'
                      : _replyingTo!.message,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 20, color: Colors.grey[600]),
            onPressed: () {
              setState(() {
                _replyingTo = null;
              });
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.blue[700], size: 24),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

