import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/core/theme/app_theme.dart';
import 'package:qent/core/utils/ios_version.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart';
import 'package:qent/features/chat/presentation/pages/messages_page.dart';
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

class MainNavPageState extends ConsumerState<MainNavPage> {
  int _currentIndex = 0;
  bool _useLiquidBar = false;

  @override
  void initState() {
    super.initState();
    IosVersion.isIOS26OrLater().then((value) {
      if (mounted && value) setState(() => _useLiquidBar = true);
    });
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

    if (_useLiquidBar) {
      // iOS 26: bar floats as an overlay; content scrolls all the way to the
      // screen edge and dips under the translucent bar (Apple Liquid Glass behavior).
      return Scaffold(
        backgroundColor: context.bgPrimary,
        body: Stack(
          children: [
            IndexedStack(
              index: _currentIndex,
              children: _pages,
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LiquidTabBar(
                currentIndex: _currentIndex,
                onTap: _onTap,
                profilePhotoUrl: profilePhotoUrl,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.bgPrimary,
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentIndex,
        onTap: _onTap,
      ),
    );
  }
}
