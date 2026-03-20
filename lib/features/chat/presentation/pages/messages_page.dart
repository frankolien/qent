import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qent/core/widgets/profile_image_widget.dart';
import 'package:qent/features/chat/domain/models/chat.dart';
import 'package:qent/features/chat/presentation/controllers/chat_controller.dart';
import 'package:qent/features/chat/presentation/pages/chat_detail_page.dart';
import 'package:qent/features/chat/presentation/providers/online_status_providers.dart';
import 'package:qent/features/chat/presentation/widgets/chat_skeleton.dart';

class MessagesPage extends ConsumerStatefulWidget {
  const MessagesPage({super.key});

  @override
  ConsumerState<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends ConsumerState<MessagesPage> {
  String _searchQuery = '';
  bool _showNoChatsTimeout = false;
  Timer? _pollTimer;
  int _selectedFilter = 0;

  final _filters = const ['All', 'Hosting', 'Traveling', 'Support'];

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showNoChatsTimeout = true);
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) ref.invalidate(chatsStreamProvider);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  String _formatPreview(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('/uploads/') || lower.contains('cloudinary')) {
      if (lower.endsWith('.m4a') || lower.endsWith('.aac') || lower.endsWith('.mp3') || lower.endsWith('.ogg') || lower.endsWith('.wav') || lower.endsWith('.opus')) {
        return '🎤 Voice message';
      }
      if (lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png') || lower.endsWith('.gif') || lower.endsWith('.webp')) {
        return '📷 Photo';
      }
    }
    return message;
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      final hour = dateTime.hour > 12
          ? dateTime.hour - 12
          : (dateTime.hour == 0 ? 12 : dateTime.hour);
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = dateTime.hour >= 12 ? 'pm' : 'am';
      return '$hour:$minute $period';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopIcons(),
            _buildTitle(),
            const SizedBox(height: 16),
            _buildFilterTabs(),
            const SizedBox(height: 8),
            Expanded(child: _buildChatList()),
          ],
        ),
      ),
    );
  }

  Widget _buildTopIcons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _buildCircleIcon(Icons.search_rounded, onTap: () {
            _showSearchSheet();
          }),
          const SizedBox(width: 12),
          _buildCircleIcon(Icons.settings_outlined, onTap: () {}),
        ],
      ),
    );
  }

  Widget _buildCircleIcon(IconData icon, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: Center(
          child: Icon(icon, size: 22, color: const Color(0xFF1A1A1A)),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Text(
        'Messages',
        style: GoogleFonts.roboto(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF1A1A1A),
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, index) {
          final isSelected = _selectedFilter == index;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedFilter = index);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF1A1A1A) : Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
                border: isSelected
                    ? null
                    : Border.all(color: Colors.grey[300]!, width: 1),
              ),
              child: Center(
                child: Text(
                  _filters[index],
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.grey[600],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChatList() {
    final chatsAsync = ref.watch(chatsStreamProvider);

    if (chatsAsync.hasValue) {
      if (_showNoChatsTimeout) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _showNoChatsTimeout = false);
        });
      }

      final chats = chatsAsync.value!;

      // Apply search filter
      var filteredChats = _searchQuery.isEmpty
          ? chats
          : chats.where((chat) {
              return chat.userName.toLowerCase().contains(_searchQuery) ||
                  chat.lastMessage.toLowerCase().contains(_searchQuery);
            }).toList();

      if (filteredChats.isEmpty) {
        return _buildEmptyState();
      }

      return ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.only(top: 8),
        itemCount: filteredChats.length,
        itemBuilder: (_, idx) => _buildSwipeableChatItem(filteredChats[idx]),
      );
    }

    return chatsAsync.when(
      data: (_) => const SizedBox.shrink(),
      loading: () {
        if (_showNoChatsTimeout) return _buildEmptyState();
        return const ChatListSkeleton();
      },
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Error loading messages',
              style: GoogleFonts.roboto(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                ref.invalidate(chatsStreamProvider);
                ref.read(chatsStreamProvider);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Retry',
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.forum_outlined,
            size: 56,
            color: Colors.grey[800],
          ),
          const SizedBox(height: 20),
          Text(
            'You don\u2019t have any messages',
            style: GoogleFonts.roboto(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'When you receive a new message,\nit will appear here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.roboto(
              fontSize: 14,
              color: Colors.grey[500],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeableChatItem(Chat chat) {
    return Dismissible(
      key: Key(chat.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Colors.red,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 22),
            SizedBox(height: 2),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        HapticFeedback.heavyImpact();
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Text('Delete Chat',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                content: Text(
                  'Delete your conversation with ${chat.userName}? This cannot be undone.',
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text('Cancel',
                        style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Delete',
                        style: TextStyle(
                            color: Colors.red, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (direction) async {
        HapticFeedback.mediumImpact();
        try {
          final chatController = ref.read(chatControllerProvider);
          await chatController.deleteConversation(chat.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Chat deleted')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to delete chat'),
                backgroundColor: Colors.red,
              ),
            );
            ref.invalidate(chatsStreamProvider);
          }
        }
      },
      child: _buildChatItem(chat),
    );
  }

  Widget _buildChatItem(Chat chat) {
    final hasUnread = chat.unreadCount > 0;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ChatDetailPage(chat: chat)),
        );
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar with online indicator
                Consumer(
                  builder: (context, ref, child) {
                    final onlineAsync =
                        ref.watch(onlineStatusStreamProvider(chat.userId));
                    final isOnline = onlineAsync.value ?? false;

                    return SizedBox(
                      width: 56,
                      height: 56,
                      child: Stack(
                        children: [
                          ProfileImageWidget(userId: chat.userId, size: 56),
                          if (isOnline)
                            Positioned(
                              bottom: 2,
                              left: 2,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4CAF50),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2.5),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 16),
                // Name + message
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: Name + unread badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              chat.userName,
                              style: GoogleFonts.roboto(
                                fontSize: 16,
                                fontWeight: hasUnread
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: const Color(0xFF1A1A1A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasUnread) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                color: Color(0xFF5B7BF9),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  chat.unreadCount > 99
                                      ? '99'
                                      : '${chat.unreadCount}',
                                  style: GoogleFonts.roboto(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Row 2: Message preview + time
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _formatPreview(chat.lastMessage),
                              style: GoogleFonts.roboto(
                                fontSize: 14,
                                color: hasUnread
                                    ? Colors.grey[700]
                                    : Colors.grey[500],
                                fontWeight: hasUnread
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _formatTime(chat.lastMessageTime),
                            style: GoogleFonts.roboto(
                              fontSize: 13,
                              color: Colors.grey[400],
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Divider
          Padding(
            padding: const EdgeInsets.only(left: 96),
            child: Divider(height: 1, thickness: 0.5, color: Colors.grey[200]),
          ),
        ],
      ),
    );
  }

  void _showSearchSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  autofocus: true,
                  onChanged: (value) {
                    setState(() => _searchQuery = value.toLowerCase());
                  },
                  style: GoogleFonts.roboto(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Search messages...',
                    hintStyle: GoogleFonts.roboto(
                      fontSize: 16,
                      color: Colors.grey[400],
                    ),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      // Clear search when sheet is dismissed
      setState(() => _searchQuery = '');
    });
  }
}
