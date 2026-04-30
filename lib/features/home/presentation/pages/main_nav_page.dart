import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/core/providers/user_cache_provider.dart';
import 'package:qent/core/services/notification_service.dart';
import 'package:qent/core/services/websocket_service.dart';
import 'package:qent/core/theme/app_theme.dart';
import 'package:qent/core/utils/ios_version.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart';
import 'package:qent/features/chat/domain/models/chat.dart';
import 'package:qent/features/chat/presentation/controllers/chat_controller.dart';
import 'package:qent/features/chat/presentation/pages/chat_detail_page.dart';
import 'package:qent/features/chat/presentation/pages/messages_page.dart';
import 'package:qent/features/chat/presentation/pages/voice_call_page.dart';
import 'package:qent/features/home/presentation/pages/home_page.dart';
import 'package:qent/features/home/presentation/widgets/custom_bottom_nav.dart';
import 'package:qent/features/home/presentation/widgets/liquid_tab_bar.dart';
import 'package:qent/features/profile/presentation/pages/profile_page.dart';
import 'package:qent/features/search/presentation/pages/search_page.dart';
import 'package:qent/features/trips/presentation/pages/trips_page.dart';

class MainNavPage extends ConsumerStatefulWidget {
  static final globalKey = GlobalKey<MainNavPageState>();

  const MainNavPage({super.key});

  @override
  ConsumerState<MainNavPage> createState() => MainNavPageState();
}

class MainNavPageState extends ConsumerState<MainNavPage>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _useLiquidBar = false;
  bool _handlingDeepLink = false;
  StreamSubscription<WsEvent>? _wsSub;
  // True while a VoiceCallPage is on top of the navigator. Used to drop
  // duplicate `call_offer` frames the server retransmits before the
  // callee answers — without this, we'd push a second call screen on
  // top of the first.
  bool _callInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    IosVersion.isIOS26OrLater().then((value) {
      if (mounted && value) setState(() => _useLiquidBar = true);
    });

    // First-launch case: a notification tap that fired before this page
    // was mounted left a pending conversation id on NotificationService.
    // Drain it on the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumePendingNotificationTap();
    });

    // Global incoming-call listener. Lives here (not on chat detail)
    // because calls must land regardless of which screen the callee is
    // currently on.
    final ws = ref.read(wsServiceProvider);
    _wsSub = ws.events.listen((event) {
      if (!mounted) return;
      if (event.type == 'call_offer') {
        _handleIncomingCall(event.payload);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _wsSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Background-tap case: user tapped a push while the app was
    // backgrounded; onMessageOpenedApp fires, sets pendingConversationTap,
    // and the app resumes. Pick up the deep link as soon as we're foreground.
    if (state == AppLifecycleState.resumed) {
      _consumePendingNotificationTap();
      // Nudge the WS back online ASAP after foregrounding so an incoming
      // call_offer landing right after resume doesn't get dropped.
      // connect() is a no-op if we're already connected.
      ref.read(wsServiceProvider).connect();
    }
  }

  Future<void> _handleIncomingCall(Map<String, dynamic> payload) async {
    if (_callInFlight) return;

    final senderId = payload['sender_id'] as String? ?? '';
    final conversationId = payload['conversation_id'] as String? ?? '';
    if (senderId.isEmpty || conversationId.isEmpty) return;

    // Best-effort caller name. Falls back to "Caller" if the user lookup
    // fails or hasn't completed yet — we don't want to delay the ring UI
    // on a profile fetch.
    String callerName = 'Caller';
    try {
      final user = await ref.read(userDataProvider(senderId).future);
      final name = user?['fullName'] as String?;
      if (name != null && name.isNotEmpty) callerName = name;
    } catch (_) {}

    if (!mounted) return;
    _callInFlight = true;
    final navigator = Navigator.of(context, rootNavigator: true);
    await navigator.push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => VoiceCallPage(
        targetId: senderId,
        targetName: callerName,
        conversationId: conversationId,
        isOutgoing: false,
        incomingOffer: payload,
      ),
    ));
    _callInFlight = false;
  }

  Future<void> _consumePendingNotificationTap() async {
    if (_handlingDeepLink) return;
    final svc = NotificationService();
    final convoId = svc.pendingConversationTap;
    if (convoId == null || convoId.isEmpty) return;

    _handlingDeepLink = true;
    svc.pendingConversationTap = null;
    // Tapping a notification should always clear the banner for that
    // chat from the tray. The chat detail page also clears on init,
    // but this covers cases where the chat couldn't be found (e.g.
    // network failure on the conversations refresh) and the page
    // never opens.
    svc.clearNotificationsForConversation(convoId);

    try {
      // Find the chat in the cached conversations list. Force a fresh fetch
      // first so we don't navigate to a stale snapshot — the user just got
      // a notification, so the conversation likely exists or was just bumped.
      final dataSource = ref.read(apiChatDataSourceProvider);
      late List<Chat> chats;
      try {
        chats = await dataSource.getConversations();
      } catch (_) {
        chats = const [];
      }

      final chat = chats.where((c) => c.id == convoId).cast<Chat?>().firstWhere(
            (_) => true,
            orElse: () => null,
          );
      if (!mounted || chat == null) return;

      // Make sure the messages tab is the visible one, so the back-nav
      // from the chat detail returns somewhere sensible.
      setState(() => _currentIndex = 2);

      // Pop any chat detail that might already be on top (e.g. user was
      // looking at chat A and tapped a notification for chat B). Then push
      // the requested chat.
      final navigator = Navigator.of(context);
      while (navigator.canPop()) {
        navigator.pop();
      }
      navigator.push(MaterialPageRoute(
        builder: (_) => ChatDetailPage(chat: chat),
      ));

      // Refresh the chats list provider so the unread badges update.
      ref.invalidate(chatsStreamProvider);
    } finally {
      _handlingDeepLink = false;
    }
  }

  void switchToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  late final List<Widget> _pages = [
    HomePage(key: HomePage.globalKey),
    const SearchPage(),
    const MessagesPage(),
    const TripsPage(),
    const ProfilePage(),
  ];

  void _onTap(int index) {
    if (index == _currentIndex && index == 0) {
      HomePage.globalKey.currentState?.scrollToTopAndRefresh();
    } else {
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profilePhotoUrl = ref.watch(authControllerProvider).user?.profilePhotoUrl;

    final bar = _useLiquidBar
        ? LiquidTabBar(
            currentIndex: _currentIndex,
            onTap: _onTap,
            profilePhotoUrl: profilePhotoUrl,
          )
        : CustomBottomNav(
            currentIndex: _currentIndex,
            onTap: _onTap,
          );

    // Strip system bottom safe-area inset so tab content extends under the
    // floating bar. Pages that use SafeArea(bottom: true) will no longer push up.
    final mq = MediaQuery.of(context);
    final mqWithoutBottomInset = mq.copyWith(
      padding: mq.padding.copyWith(bottom: 0),
      viewPadding: mq.viewPadding.copyWith(bottom: 0),
    );

    return Scaffold(
      backgroundColor: context.bgPrimary,
      body: Stack(
        children: [
          MediaQuery(
            data: mqWithoutBottomInset,
            child: IndexedStack(
              index: _currentIndex,
              children: _pages,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: bar,
          ),
        ],
      ),
    );
  }
}
