import 'package:cached_network_image/cached_network_image.dart';
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
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:qent/core/theme/app_theme.dart';

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
    // Mark this conversation as active so the server suppresses push
    // notifications while the user has it open.
    ws.setActiveConversation(widget.chat.id);
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
    try {
      // Use the recorder's own permission check (more reliable than permission_handler)
      final hasPermission = await _recorder.hasPermission();
      print('[Voice] Recorder hasPermission: $hasPermission');

      if (!hasPermission) {
        print('[Voice] No mic permission from recorder');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission required. Check Settings > Qent > Microphone.')),
          );
        }
        return;
      }

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      print('[Voice] Starting recording at: $path');

      await _recorder.start(path: path, encoder: AudioEncoder.aacLc);
      print('[Voice] Recording started!');
      setState(() => _isRecording = true);
      HapticFeedback.heavyImpact();
    } catch (e) {
      print('[Voice] FAILED to start recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start recording: $e')),
        );
      }
    }
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

    // Stop typing indicator + clear active conversation via WebSocket so the
    // server resumes sending push notifications for messages from this user.
    try {
      final ws = ref.read(wsServiceProvider);
      ws.sendTyping(conversationId: widget.chat.id, isTyping: false);
      ws.setActiveConversation(null);
    } catch (e) {
      debugPrint('[ChatDetail] Failed to clear WS state on dispose: $e');
    }

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
        decoration: BoxDecoration(
          color: context.bgPrimary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
              color: isDestructive ? Colors.red : context.textPrimary,
              size: 24,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: isDestructive ? Colors.red : context.textPrimary,
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
      backgroundColor: context.bgPrimary,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
            decoration: BoxDecoration(
              color: context.bgPrimary,
              border: Border(bottom: BorderSide(color: context.borderColor, width: 0.5)),
            ),
            child: Row(
              children: [
                // Circular back button
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : const Color(0xFFE5E5E5),
                      ),
                    ),
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: context.textPrimary),
                  ),
                ),
                const SizedBox(width: 12),
                // Avatar with online dot
                Consumer(
                  builder: (context, ref, _) {
                    final onlineAsync = ref.watch(onlineStatusStreamProvider(widget.chat.userId));
                    final isOnline = onlineAsync.value ?? false;
                    return SizedBox(
                      width: 48, height: 48,
                      child: Stack(
                        children: [
                          ProfileImageWidget(userId: widget.chat.userId, size: 48),
                          if (isOnline)
                            Positioned(
                              bottom: 0, right: 0,
                              child: Container(
                                width: 14, height: 14,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4CAF50),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: context.bgPrimary, width: 2),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                // Name + status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.chat.userName,
                        style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700,
                          color: context.textPrimary,
                          height: 1.2,
                        ),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Consumer(
                        builder: (context, ref, _) {
                          final onlineAsync = ref.watch(onlineStatusStreamProvider(widget.chat.userId));
                          final isOnline = onlineAsync.value ?? false;
                          return Text(
                            isOnline ? 'Online' : 'Offline',
                            style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w400,
                              color: context.textPrimary,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // Video call
                IconButton(
                  icon: Icon(Icons.videocam_outlined,
                      size: 26, color: context.textPrimary),
                  onPressed: () {},
                ),
                // Voice call
                IconButton(
                  icon: Icon(Icons.phone_outlined,
                      size: 24, color: context.textPrimary),
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
          ),
        ),
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
        return GestureDetector(
          onTap: () => _showFullImage(message.message),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 240, maxHeight: 320),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isMe ? 20 : 6),
                bottomRight: Radius.circular(isMe ? 6 : 20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: context.isDark ? 0.4 : 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isMe ? 20 : 6),
                bottomRight: Radius.circular(isMe ? 6 : 20),
              ),
              child: CachedNetworkImage(
                imageUrl: message.message,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  width: 220, height: 180,
                  color: context.isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : const Color(0xFFF1F1F2),
                  child: Center(
                    child: SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.textTertiary,
                      ),
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  width: 220, height: 120,
                  color: context.isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : const Color(0xFFF1F1F2),
                  child: Icon(Icons.broken_image_rounded,
                      color: context.textTertiary, size: 32),
                ),
              ),
            ),
          ),
        );

      case MessageType.voice:
        return _VoiceMessageBubble(url: message.message, isMe: isMe);

      case MessageType.text:
        final myTextColor = context.isDark ? Colors.black : Colors.white;
        return Text(
          message.message,
          style: TextStyle(
            fontSize: 15.5,
            color: isMe ? myTextColor : context.textPrimary,
            fontWeight: FontWeight.w400,
            height: 1.35,
            letterSpacing: -0.1,
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
              child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContextBanner() {
    final hasCarName = widget.chat.carName != null && widget.chat.carName!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: context.bgPrimary,
        border: Border(
          bottom: BorderSide(color: context.borderColor, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Centered partner subtitle (Figma style)
          if (widget.chat.isPartner) ...[
            Text(
              widget.chat.userName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.chat.userName.split(' ').first} is a partner of QENT',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            if (hasCarName) const SizedBox(height: 14),
          ],
          // Compact car chip
          if (hasCarName)
            _buildCarChip(),
        ],
      ),
    );
  }

  Widget _buildCarChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.isDark
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.directions_car_rounded,
              size: 16, color: context.textPrimary.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              widget.chat.carName!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    // Watch the merged provider (server messages + local optimistic pending
    // sends) so a freshly-sent message appears in the list immediately, with
    // a clock icon, before the API call returns.
    final messagesAsync = ref.watch(chatMessagesProvider(widget.chat.id));

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
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: context.isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFEFEFEF),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _formatDate(date),
            style: TextStyle(
              fontSize: 12,
              color: context.textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, {required bool showAvatar, required bool isMe}) {
    return Padding(
      padding: EdgeInsets.only(
        left: isMe ? 60 : 16,
        right: isMe ? 16 : 60,
        top: showAvatar ? 10 : 2,
        bottom: 2,
      ),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            if (showAvatar)
              ProfileImageWidget(userId: message.senderId, size: 32)
            else
              const SizedBox(width: 32),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Reply preview
                if (message.replyTo != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: context.bgSecondary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border(left: BorderSide(color: context.borderColor, width: 3)),
                    ),
                    child: Text(
                      message.replyTo!.message.length > 50
                          ? '${message.replyTo!.message.substring(0, 50)}...'
                          : message.replyTo!.message,
                      style: TextStyle(fontSize: 12, color: context.textSecondary),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                // Message bubble
                Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                  padding: message.type == MessageType.image
                      ? EdgeInsets.zero
                      : const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  decoration: BoxDecoration(
                    color: message.type == MessageType.image
                        ? Colors.transparent
                        : (isMe
                            ? (context.isDark ? Colors.white : const Color(0xFF1A1A1A))
                            : (context.isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : const Color(0xFFF1F1F2))),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(22),
                      topRight: const Radius.circular(22),
                      bottomLeft: Radius.circular(isMe ? 22 : 6),
                      bottomRight: Radius.circular(isMe ? 6 : 22),
                    ),
                  ),
                  child: _buildMessageContent(message, isMe),
                ),
                // Timestamp + read receipt
                Padding(
                  padding: const EdgeInsets.only(top: 5, left: 4, right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatMessageTime(message.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: context.textTertiary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        _buildStatusIcon(message),
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

  Widget _buildStatusIcon(ChatMessage message) {
    switch (message.status) {
      case MessageStatus.sending:
        return Icon(Icons.access_time_rounded,
            size: 13, color: context.textTertiary);
      case MessageStatus.failed:
        return GestureDetector(
          onTap: () => _showFailedMessageOptions(message),
          child: Icon(Icons.error_outline_rounded,
              size: 14, color: Colors.red.shade400),
        );
      case MessageStatus.sent:
        return Icon(
          message.isRead ? Icons.done_all_rounded : Icons.done_rounded,
          size: 14,
          color: context.textPrimary.withValues(alpha: 0.7),
        );
    }
  }

  void _showFailedMessageOptions(ChatMessage message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.bgPrimary,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.refresh_rounded, color: context.textPrimary),
              title: Text('Retry send', style: TextStyle(color: context.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(chatControllerProvider).retrySend(
                      chatId: widget.chat.id,
                      failed: message,
                    );
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400),
              title: Text('Delete', style: TextStyle(color: Colors.red.shade400)),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(chatControllerProvider).dismissFailed(
                      chatId: widget.chat.id,
                      tempId: message.id,
                    );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 60, top: 8, bottom: 8),
      child: Row(
        children: [
          ProfileImageWidget(userId: widget.chat.userId, size: 32),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: context.isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFF1F1F2),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
                bottomLeft: Radius.circular(6),
                bottomRight: Radius.circular(22),
              ),
            ),
            child: AnimatedBuilder(
              animation: _typingAnimationController,
              builder: (context, _) {
                final t = _typingAnimationController.value;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    // Each dot bobs on a phase-shifted sine wave
                    final phase = (t * 2 * math.pi) - (i * 0.7);
                    final offset = (1 - ((1 + math.cos(phase)) / 2)).clamp(0.4, 1.0);
                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2.5),
                      child: Container(
                        width: 7, height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: context.textPrimary.withValues(alpha: offset * 0.7),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
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
            decoration: BoxDecoration(
              color: context.bgPrimary,
              border: Border(top: BorderSide(color: context.borderColor, width: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  width: 10, height: 10,
                  decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Recording...', style: TextStyle(fontSize: 15, color: Color(0xFFEF4444), fontWeight: FontWeight.w500)),
                ),
                GestureDetector(
                  onTap: () { _recorder.stop(); setState(() => _isRecording = false); HapticFeedback.lightImpact(); },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: context.bgSecondary, shape: BoxShape.circle),
                    child: Icon(Icons.delete_outline, color: context.textSecondary, size: 22),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _stopAndSendVoiceRecording,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
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
              bottom: MediaQuery.of(context).padding.bottom + 6,
              top: 8, left: 10, right: 10,
            ),
            decoration: BoxDecoration(
              color: context.bgPrimary,
              border: Border(top: BorderSide(color: context.borderColor, width: 0.5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Attachment button — plus icon, filled circle
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showAttachmentSheet();
                  },
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFFF1F1F2),
                    ),
                    child: Icon(Icons.add_rounded,
                        color: context.textPrimary, size: 20),
                  ),
                ),
                const SizedBox(width: 8),
                // Text field — slim pill, voice waveform inline at the right
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 110, minHeight: 36),
                    decoration: BoxDecoration(
                      color: context.inputBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            focusNode: _focusNode,
                            // Override every border slot to InputBorder.none
                            // because the global theme paints a green
                            // focusedBorder that otherwise bleeds through.
                            decoration: InputDecoration(
                              hintText: 'Message',
                              hintStyle: TextStyle(color: context.textTertiary, fontSize: 15),
                              isDense: true,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                              filled: false,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            ),
                            cursorColor: context.textPrimary,
                            maxLines: 5,
                            minLines: 1,
                            style: TextStyle(fontSize: 15, color: context.textPrimary, height: 1.2),
                          ),
                        ),
                        // Inline voice icon — only visible when the field is empty,
                        // tap-to-record. Disappears when the user starts typing
                        // (the send button to the right takes over).
                        if (!hasText && !_isUploading)
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              _startVoiceRecording();
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 12, left: 4),
                              child: Icon(
                                Icons.graphic_eq_rounded,
                                color: context.textTertiary,
                                size: 20,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Send button — only when there's text or an upload is in progress.
                if (hasText || _isUploading) ...[
                  const SizedBox(width: 8),
                  _isUploading
                      ? Padding(
                          padding: const EdgeInsets.all(6),
                          child: SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: context.textPrimary,
                            ),
                          ),
                        )
                      : GestureDetector(
                          onTap: _sendMessage,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: context.isDark
                                  ? Colors.white
                                  : const Color(0xFF1A1A1A),
                            ),
                            child: Icon(
                              Icons.arrow_upward_rounded,
                              color: context.isDark
                                  ? Colors.black
                                  : Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.bgPrimary,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAttachOption(Icons.photo_library_rounded, 'Gallery', const Color(0xFF7C4DFF), () {
                    Navigator.pop(ctx);
                    _pickAndSendImage();
                  }),
                  _buildAttachOption(Icons.camera_alt_rounded, 'Camera', const Color(0xFFFF6D00), () {
                    Navigator.pop(ctx);
                    _pickAndSendImage(fromCamera: true);
                  }),
                  _buildAttachOption(Icons.mic_rounded, 'Voice', const Color(0xFF00C853), () {
                    Navigator.pop(ctx);
                    _startVoiceRecording();
                  }),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      child: Column(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, color: context.textSecondary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
  
  Widget _buildInputReplyPreview() {
    final authState = ref.read(authControllerProvider);
    final currentUserId = authState.user?.uid ?? '';
    final isReplyFromMe = _replyingTo!.senderId == currentUserId;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: context.bgSecondary,
        border: Border(
          left: BorderSide(
            color: isReplyFromMe ? context.textPrimary : context.textSecondary,
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
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _replyingTo!.message.length > 60
                      ? '${_replyingTo!.message.substring(0, 60)}...'
                      : _replyingTo!.message,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 20, color: context.textSecondary),
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

  // Static fake waveform — same instance reuses across rebuilds
  static const _waveform = [
    0.35, 0.55, 0.75, 0.45, 0.85, 0.65, 0.95, 0.55, 0.7, 0.4,
    0.6, 0.85, 0.5, 0.75, 0.3, 0.6, 0.8, 0.45, 0.7, 0.5,
    0.4, 0.65,
  ];

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
    HapticFeedback.lightImpact();
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

    // For my bubbles (dark background) use light icons; theirs use dark
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = widget.isMe
        ? (isDark ? Colors.black : Colors.white)
        : (isDark ? Colors.white : const Color(0xFF1A1A1A));
    final dimForeground = foreground.withValues(alpha: 0.35);

    return SizedBox(
      width: 200,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/pause button — filled circle for visual weight
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: foreground.withValues(alpha: 0.15),
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: foreground,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Waveform + duration
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 24,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: List.generate(_waveform.length, (i) {
                      final barProgress = i / _waveform.length;
                      final isPlayed = barProgress <= progress;
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1.2),
                          height: 24 * _waveform[i],
                          decoration: BoxDecoration(
                            color: isPlayed ? foreground : dimForeground,
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isPlaying || _position > Duration.zero
                      ? _fmt(_position)
                      : _fmt(_duration),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: foreground.withValues(alpha: 0.6),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
