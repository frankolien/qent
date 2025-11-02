import 'package:flutter/material.dart';
import 'package:qent/features/chat/presentation/pages/messages_page.dart';
import 'package:qent/features/home/presentation/pages/home_page.dart';
import 'package:qent/features/home/presentation/widgets/custom_bottom_nav.dart';
import 'package:qent/features/notifications/presentation/pages/notifications_page.dart';
import 'package:qent/features/profile/presentation/pages/profile_page.dart';
import 'package:qent/features/search/presentation/pages/search_page.dart';

class MainNavPage extends StatefulWidget {
  const MainNavPage({super.key});

  @override
  State<MainNavPage> createState() => _MainNavPageState();
}

class _MainNavPageState extends State<MainNavPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomePage(),
    const SearchPage(),
    const MessagesPage(),
    const NotificationsPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}




