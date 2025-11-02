import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qent/core/widgets/profile_image_widget.dart';
import 'package:qent/features/chat/domain/models/chat.dart';
import 'package:qent/features/chat/presentation/controllers/chat_controller.dart';
import 'package:qent/features/chat/presentation/providers/online_status_providers.dart';
import 'package:qent/features/chat/presentation/widgets/chat_skeleton.dart';

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
  bool _isTyping = false;
  bool _hasMarkedAsRead = false;
  bool _showAttachmentOptions = false;
  late AnimationController _typingAnimationController;
  
  @override
  void initState() {
    super.initState();
    _typingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    
    _messageController.addListener(_onMessageChanged);
    _focusNode.addListener(_onFocusChanged);
  }
  
  void _onMessageChanged() {
    setState(() {
      // Trigger rebuild for input field
    });
  }
  
  void _onFocusChanged() {
    // Don't auto-hide attachment options when focus changes
    // User can toggle it manually
  }

  @override
  void dispose() {
    _messageController.removeListener(_onMessageChanged);
    _focusNode.removeListener(_onFocusChanged);
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);
    
    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMMM d, yyyy').format(date);
    }
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
                  // TODO: Implement reply functionality
                },
              ),
              _buildMenuOption(
                context,
                icon: Icons.forward,
                label: 'Forward',
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement forward functionality
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
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement delete functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Message deleted')),
              );
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

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final message = _messageController.text.trim();
    _messageController.clear();
    HapticFeedback.lightImpact();

    ref.read(chatControllerProvider).sendMessage(
      chatId: widget.chat.id,
      message: message,
      type: MessageType.text,
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
          // Partner Banner
          Container(
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
                        widget.chat.userName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Angelina is a partner of QENT',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: messages.length + (_isTyping ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == messages.length) {
                return _buildTypingIndicator();
              }
              
              final message = messages[index];
              final auth = ref.read(firebaseAuthProvider);
              final currentUserId = auth.currentUser?.uid ?? '';
              final isMe = message.senderId == currentUserId || message.senderId == 'current';
              
              // Check if we should show date separator
              final showDateSeparator = _shouldShowDateSeparator(messages, index);
              
              // Check if previous message is from same sender and within 5 minutes
              final showAvatar = index == 0 || 
                  messages[index - 1].senderId != message.senderId ||
                  message.timestamp.difference(messages[index - 1].timestamp).inMinutes > 5;
              
              // Check if next message is from same sender and within 5 minutes (to determine if this is last in group)
              final isLastInGroup = index == messages.length - 1 ||
                  messages[index + 1].senderId != message.senderId ||
                  messages[index + 1].timestamp.difference(message.timestamp).inMinutes > 5;
              
              return Column(
                children: [
                  if (showDateSeparator) _buildDateSeparator(message.timestamp),
                  GestureDetector(
                    onLongPress: () => _showMessageMenu(context, message),
                    child: _buildMessageBubble(
                      message,
                      showAvatar: showAvatar,
                      showTimestamp: isLastInGroup,
                      isMe: isMe,
                    ),
                  ),
                ],
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
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _formatDate(date),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, {required bool showAvatar, required bool showTimestamp, required bool isMe}) {
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
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.blue[600] : Colors.grey[200],
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
                // Only show timestamp and read receipts for the last message in a group
                if (showTimestamp) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatMessageTime(message.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done_all,
                          size: 14,
                          color: message.isRead ? Colors.blue[600] : Colors.grey,
                        ),
                      ],
                    ],
                  ),
                ],
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
              // Attachment button
              IconButton(
                icon: Icon(
                  _showAttachmentOptions ? Icons.close : Icons.attach_file,
                  color: _showAttachmentOptions ? Colors.blue[600] : Colors.grey,
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _showAttachmentOptions = !_showAttachmentOptions;
                  });
                },
              ),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 100),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: _focusNode.hasFocus ? Colors.blue[300]! : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: TextField(
                    controller: _messageController,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              // Emoji button or Send button
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
                  icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.grey),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    // TODO: Implement emoji picker
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

