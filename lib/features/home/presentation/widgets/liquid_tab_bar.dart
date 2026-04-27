import 'package:cupertino_native/cupertino_native.dart';
import 'package:flutter/material.dart';

/// iOS 26 Liquid Glass tab bar — wraps Serverpod's CNTabBar (native UIKit
/// host with pixel-perfect Liquid Glass fidelity). Mirrors CustomBottomNav's
/// public API so swapping is transparent.
///
/// Note: profilePhotoUrl is currently unused — CNTabBar takes SF Symbols only.
/// We accept the prop so the call site stays identical to CustomBottomNav.
class LiquidTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final String? profilePhotoUrl;

  const LiquidTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.profilePhotoUrl,
  });

  // Visual order in the bar (Search pinned right as a separate capsule):
  //   [Home, Messages, Trips, Profile,  |  Search]
  // The MainNavPage page indexes are:
  //   0 Home, 1 Search, 2 Messages, 3 Trips, 4 Profile
  // So we need to remap visual position -> page index:
  static const _pageIndexForVisualPosition = [0, 2, 3, 4, 1];

  int _visualForPage(int pageIndex) =>
      _pageIndexForVisualPosition.indexOf(pageIndex);

  @override
  Widget build(BuildContext context) {
    return CNTabBar(
      //height: 85,
      split: true,
      rightCount: 0,
      splitSpacing: 1.0,
      shrinkCentered: false,
      backgroundColor: Colors.black.withValues(alpha: 0.15),
      tint: const Color(0xFF007AFF),
      
      currentIndex: _visualForPage(currentIndex),
      onTap: (visualIndex) => onTap(_pageIndexForVisualPosition[visualIndex]),
      items: const [
        CNTabBarItem(label: 'Home', icon: CNSymbol('house.fill')),
        CNTabBarItem(label: 'Messages', icon: CNSymbol('tray.fill')),
        CNTabBarItem(label: 'Trips', icon: CNSymbol('suitcase.fill')),
        CNTabBarItem(label: 'Profile', icon: CNSymbol('person.crop.circle.fill')),
        CNTabBarItem(label:"Search",icon: CNSymbol('magnifyingglass')),
      ],
    );
  }
}
