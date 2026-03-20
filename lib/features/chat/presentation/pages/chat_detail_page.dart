import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qent/core/widgets/profile_image_widget.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart';
import 'package:qent/features/chat/domain/models/chat.dart';
import 'package:qent/features/chat/presentation/controllers/chat_controller.dart';
import 'package:qent/features/chat/presentation/providers/online_status_providers.dart';
import 'package:qent/features/chat/presentation/pages/new_chat_page.dart';
import 'package:qent/features/chat/presentation/widgets/chat_skeleton.dart';
import 'package:qent/core/services/websocket_service.dart';
import 'package:qent/features/chat/presentation/pages/voice_call_page.dart';
import 'package:qent/core/services/file_upload_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:io';

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
  ReplyInfo? _replyingTo;
  Timer? _typingTimer;
  Timer? _pollTimer;
  bool _isUserTyping = false;
  late AnimationController _typingAnimationController;
  ChatController? _chatController;
  StreamSubscription<WsEvent>? _wsSub;
  bool _otherUserTyping = false;
  bool _isRecording = false;
  bool _isUploading = false;
  final Record _recorder = Record();

  @override
  void initState() {
    super.initState();
    _typingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _messageController.addListener(_onMessageChanged);
    _focusNode.addListener(_onFocusChanged);

    // Listen for real-time messages via WebSocket
    final ws = ref.read(wsServiceProvider);
    _wsSub = ws.events.listen((event) {
      if (!mounted) return;
      if (event.type == 'new_message' && event.payload['conversation_id'] == widget.chat.id) {
        // Refresh messages when we receive a new one for this conversation
        ref.invalidate(messagesStreamProvider(widget.chat.id));
        _scrollToBottom();
      } else if (event.type == 'message_sent' && event.payload['conversation_id'] == widget.chat.id) {
        ref.invalidate(messagesStreamProvider(widget.chat.id));
        _scrollToBottom();
      } else if (event.type == 'typing' && event.payload['conversation_id'] == widget.chat.id) {
        setState(() => _otherUserTyping = event.payload['is_typing'] == true);
        // Auto-clear after 3s
        if (_otherUserTyping) {
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) setState(() => _otherUserTyping = false);
          });
        }
      } else if (event.type == 'call_offer') {
        _handleIncomingCall(event.payload);
      }
    });

    // Fallback poll every 15s in case WS drops
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        ref.invalidate(messagesStreamProvider(widget.chat.id));
      }
    });

    _updateTypingStatus();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _pickAndSendImage({bool fromCamera = false}) async {
    final picker = ImagePicker();
    final picked = fromCamera
        ? await picker.pickImage(source: ImageSource.camera, imageQuality: 70)
        : await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;

    setState(() => _isUploading = true);
    final url = await FileUploadService.upload(File(picked.path));
    setState(() => _isUploading = false);

    if (url != null && mounted) {
      final chatController = ref.read(chatControllerProvider);
      await chatController.sendMessage(
        chatId: widget.chat.id,
        message: url,
        type: MessageType.image,
      );
      ref.invalidate(messagesStreamProvider(widget.chat.id));
      _scrollToBottom();
    }
  }

  Future<void> _startVoiceRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) return;

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(path: path, encoder: AudioEncoder.aacLc);
    setState(() => _isRecording = true);
    HapticFeedback.heavyImpact();
  }

  Future<void> _stopAndSendVoiceRecording() async {
    final path = await _recorder.stop();
    setState(() => _isRecording = false);
    HapticFeedback.mediumImpact();

    if (path == null) return;
    final file = File(path);
    if (!await file.exists()) return;

    setState(() => _isUploading = true);
    final url = await FileUploadService.upload(file);
    setState(() => _isUploading = false);

    if (url != null && mounted) {
      final chatController = ref.read(chatControllerProvider);
      await chatController.sendMessage(
        chatId: widget.chat.id,
        message: url,
        type: MessageType.voice,
      );
      ref.invalidate(messagesStreamProvider(widget.chat.id));
      _scrollToBottom();
    }
    // Clean up temp file
    try { await file.delete(); } catch (_) {}
  }

  void _handleIncomingCall(Map<String, dynamic> payload) {
    final senderId = payload['sender_id'] as String? ?? '';
    if (senderId.isEmpty) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => VoiceCallPage(
        targetId: senderId,
        targetName: widget.chat.userName,
        conversationId: widget.chat.id,
        isOutgoing: false,
        incomingOffer: payload,
      ),
    ));
  }
  
  void _onMessageChanged() {
    setState(() {
      // Trigger rebuild for input field
    });
    
    // Send typing status via WebSocket
    final ws = ref.read(wsServiceProvider);
    if (_messageController.text.trim().isNotEmpty && !_isUserTyping) {
      _isUserTyping = true;
      ws.sendTyping(conversationId: widget.chat.id, isTyping: true);
    } else if (_messageController.text.trim().isEmpty && _isUserTyping) {
      _isUserTyping = false;
      ws.sendTyping(conversationId: widget.chat.id, isTyping: false);
    }

    // Reset typing timer — stop after 2s of no input
    _typingTimer?.cancel();
    if (_messageController.text.trim().isNotEmpty) {
      _typingTimer = Timer(const Duration(seconds: 2), () {
        if (mounted && _isUserTyping) {
          _isUserTyping = false;
          ws.sendTyping(conversationId: widget.chat.id, isTyping: false);
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
    _wsSub?.cancel();
    _pollTimer?.cancel();
    _typingTimer?.cancel();
    _messageController.removeListener(_onMessageChanged);
    _focusNode.removeListener(_onFocusChanged);

    // Stop typing indicator via WebSocket
    try {
      final ws = ref.read(wsServiceProvider);
      ws.sendTyping(conversationId: widget.chat.id, isTyping: false);
    } catch (_) {}

    _recorder.dispose();
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

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final message = _messageController.text.trim();
    final replyToMessageId = _replyingTo?.messageId;
    final replyTo = _replyingTo;

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

    await chatController.sendMessage(
      chatId: widget.chat.id,
      message: message,
      type: MessageType.text,
      replyToMessageId: replyToMessageId,
      replyTo: replyTo,
    );

    // Auto-scroll to bottom after messages refresh
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

        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ProfileImageWidget(
              userId: widget.chat.userId,
              size: 40,
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
                  Consumer(
                    builder: (context, ref, _) {
                      final onlineAsync = ref.watch(
                        onlineStatusStreamProvider(widget.chat.userId),
                      );
                      final isOnline = onlineAsync.value ?? false;
                      return Text(
                        isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: isOnline ? const Color(0xFF4CAF50) : Colors.grey[400],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.black),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.phone, color: Colors.black),
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => VoiceCallPage(
                  targetId: widget.chat.userId,
                  targetName: widget.chat.userName,
                  conversationId: widget.chat.id,
                  isOutgoing: true,
                ),
              ));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Partner + car context banner
          if (widget.chat.isPartner || (widget.chat.carName != null && widget.chat.carName!.isNotEmpty))
            _buildContextBanner(),
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

  Widget _buildMessageContent(ChatMessage message, bool isMe) {
    switch (message.type) {
      case MessageType.image:
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: GestureDetector(
            onTap: () => _showFullImage(message.message),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220, maxHeight: 280),
              child: Image.network(
                message.message,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    width: 180, height: 140,
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  width: 180, height: 80,
                  color: Colors.grey[200],
                  child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                ),
              ),
            ),
          ),
        );

      case MessageType.voice:
        return _VoiceMessageBubble(url: message.message, isMe: isMe);

      case MessageType.text:
        return Text(
          message.message,
          style: TextStyle(
            fontSize: 14,
            color: isMe ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w400,
          ),
          softWrap: true,
        );
    }
  }

  void _showFullImage(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContextBanner() {
    final hasCarName = widget.chat.carName != null && widget.chat.carName!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Partner badge
          if (widget.chat.isPartner)
            Padding(
              padding: EdgeInsets.only(bottom: hasCarName ? 10 : 0),
              child: Row(
                children: [
                  ProfileImageWidget(userId: widget.chat.userId, size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.chat.userName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${widget.chat.userName.split(' ').first} is a partner of QENT',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          // Car context
          if (hasCarName)
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.directions_car_rounded, size: 18, color: Color(0xFF2E7D32)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.chat.carName!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Conversation about this listing',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
              ],
            ),
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
                  final authState = ref.read(authControllerProvider);
                  final currentUserId = authState.user?.uid ?? '';
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
                  child: _buildMessageContent(message, isMe),
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
        if (_replyingTo != null) _buildInputReplyPreview(),

        // Recording bar
        if (_isRecording)
          Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + 8,
              top: 12, left: 20, right: 20,
            ),
            color: Colors.white,
            child: Row(
              children: [
                Container(
                  width: 10, height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Recording...',
                    style: TextStyle(
                      fontSize: 15, color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    _recorder.stop();
                    setState(() => _isRecording = false);
                    HapticFeedback.lightImpact();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.delete_outline, color: Colors.grey[600], size: 22),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _stopAndSendVoiceRecording,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFF22C55E),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          )
        else
          // Normal input bar
          Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + 4,
              top: 8, left: 12, right: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[200]!, width: 0.5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Camera button
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _pickAndSendImage(fromCamera: true);
                    },
                    child: Icon(Icons.camera_alt_outlined, color: Colors.grey[600], size: 26),
                  ),
                ),
                const SizedBox(width: 8),
                // Text field
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            focusNode: _focusNode,
                            decoration: InputDecoration(
                              hintText: 'Message...',
                              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10,
                              ),
                            ),
                            maxLines: 5,
                            minLines: 1,
                            textInputAction: TextInputAction.newline,
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                        // Gallery button inside text field
                        if (!hasText)
                          Padding(
                            padding: const EdgeInsets.only(right: 4, bottom: 4),
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                _pickAndSendImage();
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(Icons.photo_outlined, color: Colors.grey[500], size: 24),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Send / Mic / Upload indicator
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: _isUploading
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF1A1A1A)),
                          ),
                        )
                      : hasText
                          ? GestureDetector(
                              onTap: _sendMessage,
                              child: Container(
                                width: 42, height: 42,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1A1A1A),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                              ),
                            )
                          : GestureDetector(
                              onTap: _startVoiceRecording,
                              child: Container(
                                width: 42, height: 42,
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.mic_rounded, color: Colors.grey[700], size: 24),
                              ),
                            ),
                ),
              ],
            ),
          ),
      ],
    );
  }
  
  Widget _buildInputReplyPreview() {
    final authState = ref.read(authControllerProvider);
    final currentUserId = authState.user?.uid ?? '';
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

}

/// Playable voice message bubble with play/pause and progress
class _VoiceMessageBubble extends StatefulWidget {
  final String url;
  final bool isMe;
  const _VoiceMessageBubble({required this.url, required this.isMe});

  @override
  State<_VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<_VoiceMessageBubble> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() { _isPlaying = false; _position = Duration.zero; });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
    } else {
      await _player.play(UrlSource(widget.url));
      setState(() => _isPlaying = true);
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(1, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: widget.isMe ? Colors.white.withValues(alpha: 0.2) : const Color(0xFF1A1A1A).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: widget.isMe ? Colors.white : const Color(0xFF1A1A1A),
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: widget.isMe ? Colors.white.withValues(alpha: 0.15) : Colors.grey[300],
                    color: widget.isMe ? Colors.white : const Color(0xFF1A1A1A),
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _isPlaying || _position > Duration.zero ? _fmt(_position) : _fmt(_duration),
                style: TextStyle(
                  fontSize: 11,
                  color: widget.isMe ? Colors.white.withValues(alpha: 0.6) : Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
