import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/core/widgets/profile_image_widget.dart';
import 'package:qent/features/chat/domain/models/chat.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart';
import 'package:qent/features/chat/presentation/controllers/chat_controller.dart';
import 'package:qent/features/chat/presentation/pages/chat_detail_page.dart';
import 'package:qent/features/chat/presentation/pages/add_story_page.dart';
import 'package:qent/features/chat/presentation/pages/story_viewer_page.dart';
import 'package:qent/features/chat/presentation/providers/online_status_providers.dart';
import 'package:qent/features/chat/presentation/providers/stories_providers.dart';
import 'package:qent/features/chat/presentation/widgets/chat_skeleton.dart';

class MessagesPage extends ConsumerStatefulWidget {
  const MessagesPage({super.key});

  @override
  ConsumerState<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends ConsumerState<MessagesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showNoChatsTimeout = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _showNoChatsTimeout = true;
        });
      }
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        ref.invalidate(chatsStreamProvider);
        ref.invalidate(storiesProvider);
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate =
        DateTime(dateTime.year, dateTime.month, dateTime.day);

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
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            // Thin divider matching screenshot
            Container(
              height: 1,
              color: const Color(0xFFE8E8E8),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildSearchBar(),
                  _buildStoriesSection(),
                  _buildChatList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      child: Row(
        children: [
          // Back arrow in outlined circle
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFDDDDDD),
                  width: 1.2,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.arrow_back_ios_new,
                  size: 16,
                  color: Color(0xFF2C2C2C),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Profile image
          Consumer(
            builder: (context, ref, child) {
              final authState = ref.watch(authControllerProvider);
              final userId = authState.user?.uid;
              return ProfileImageWidget(
                userId: userId,
                size: 40,
              );
            },
          ),
          const SizedBox(width: 12),
          // "Chats" title
          const Text(
            'Chats',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          // Three-dot menu in outlined circle
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFDDDDDD),
                  width: 1.2,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.more_horiz,
                  size: 22,
                  color: Color(0xFF2C2C2C),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFFE0E0E0),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 18),
            Icon(Icons.search, color: Colors.grey[600], size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
                style: const TextStyle(
                    fontSize: 15, color: Color(0xFF1A1A1A)),
                decoration: InputDecoration(
                  hintText: 'Search your dream car.....',
                  hintStyle:
                      TextStyle(color: Colors.grey[600], fontSize: 15),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child:
                      Icon(Icons.clear, color: Colors.grey[400], size: 20),
                ),
              ),
            if (_searchQuery.isEmpty) const SizedBox(width: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildStoriesSection() {
    final storiesAsync = ref.watch(storiesProvider);
    final authState = ref.watch(authControllerProvider);
    final isHost = authState.user?.role == 'Host';

    // Check if there are any stories to show
    final hasStories = storiesAsync.whenOrNull(
      data: (groups) => groups.isNotEmpty,
    ) ?? false;

    // Hide entire section if not a host and no stories
    if (!isHost && !hasStories) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: SizedBox(
        height: 100,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          children: [
            // "Add story" — only for hosts
            if (isHost)
              Padding(
                padding: const EdgeInsets.only(right: 18),
                child: _buildAddStoryItem(),
              ),
            // Story items from API
            ...storiesAsync.when(
              data: (groups) => groups.map(
                (group) => Padding(
                  padding: const EdgeInsets.only(right: 18),
                  child: _buildStoryItem(group),
                ),
              ),
              loading: () => <Widget>[],
              error: (_, __) => <Widget>[],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddStoryItem() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddStoryPage()),
        );
      },
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFD5D5D5),
                  width: 1.5,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.add,
                  size: 28,
                  color: Color(0xFF888888),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add story',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF2C2C2C),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryItem(HostStoryGroup group) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StoryViewerPage(
              hostGroup: group,
              onMessageTap: () {},
            ),
          ),
        );
      },
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Blue ring around avatar
            Container(
              width: 68,
              height: 68,
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF5B8DEF), // Blue story ring
              ),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                padding: const EdgeInsets.all(2),
                child: ClipOval(
                  child: group.hostPhoto.isNotEmpty
                      ? Image.network(
                          group.hostPhoto,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[300],
                            child: Icon(Icons.person,
                                color: Colors.grey[500], size: 28),
                          ),
                        )
                      : Container(
                          color: Colors.grey[300],
                          child: Icon(Icons.person,
                              color: Colors.grey[500], size: 28),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              group.hostName.split(' ').first,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF2C2C2C),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatList() {
    final chatsAsync = ref.watch(chatsStreamProvider);

    if (chatsAsync.hasValue) {
      if (_showNoChatsTimeout) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _showNoChatsTimeout = false;
            });
          }
        });
      }

      final chats = chatsAsync.value!;

      final filteredChats = _searchQuery.isEmpty
          ? chats
          : chats.where((chat) {
              return chat.userName
                      .toLowerCase()
                      .contains(_searchQuery) ||
                  chat.lastMessage
                      .toLowerCase()
                      .contains(_searchQuery);
            }).toList();

      if (filteredChats.isEmpty) {
        return Padding(
          padding: const EdgeInsets.all(32.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline,
                    size: 56, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isEmpty
                      ? 'No chats yet'
                      : 'No chats found',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                if (_searchQuery.isEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Start a conversation by tapping the + button',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        );
      }

      return Column(
        children: filteredChats
            .map((chat) => _buildSwipeableChatItem(chat))
            .toList(),
      );
    }

    return chatsAsync.when(
      data: (_) => const SizedBox.shrink(),
      loading: () {
        if (_showNoChatsTimeout) {
          return Padding(
            padding: const EdgeInsets.all(32.0),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 56, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text(
                    'No chats yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Start a conversation by tapping the + button',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        return const ChatListSkeleton();
      },
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 56, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Error loading chats',
              style: TextStyle(color: Colors.red[600]),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                ref.invalidate(chatsStreamProvider);
                ref.read(chatsStreamProvider);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
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
                  fontSize: 11),
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
                    borderRadius: BorderRadius.circular(16)),
                title: const Text('Delete Chat',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 17)),
                content: Text(
                  'Delete your conversation with ${chat.userName}? This cannot be undone.',
                  style: const TextStyle(
                      fontSize: 14, color: Colors.black87),
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
                            color: Colors.red,
                            fontWeight: FontWeight.w600)),
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
                  backgroundColor: Colors.red),
            );
            ref.invalidate(chatsStreamProvider);
          }
        }
      },
      child: _buildChatItemWithDivider(chat),
    );
  }

  Widget _buildChatItemWithDivider(Chat chat) {
    return Column(
      children: [
        _buildChatItem(chat),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Divider(
            height: 1,
            thickness: 1.0,
            color: Colors.grey[200],
          ),
        ),
      ],
    );
  }

  Widget _buildChatItem(Chat chat) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailPage(chat: chat),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar with online dot
            Consumer(
              builder: (context, ref, child) {
                final onlineStatusAsync = ref
                    .watch(onlineStatusStreamProvider(chat.userId));
                final isOnline = onlineStatusAsync.value ?? false;

                return SizedBox(
                  width: 60,
                  height: 60,
                  child: Stack(
                    children: [
                      ProfileImageWidget(
                        userId: chat.userId,
                        size: 60,
                      ),
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
                              border: Border.all(
                                  color: const Color(0xFFFAFAFA),
                                  width: 2.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(width: 14),
            // Name + message
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Row 1: Name + Badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.userName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: chat.unreadCount > 0
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: const Color(0xFF1A1A1A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (chat.unreadCount > 0)
                        Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: Color(0xFF5B8DEF),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              chat.unreadCount > 99
                                  ? '99+'
                                  : '${chat.unreadCount}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Row 2: Message + Time
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.lastMessage,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(chat.lastMessageTime),
                        style: TextStyle(
                          fontSize: 12,
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
    );
  }
}
