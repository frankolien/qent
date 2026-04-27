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

  @override
  Widget build(BuildContext context) {
    return CNTabBar(
      currentIndex: currentIndex,
      onTap: onTap,
      items: const [
        CNTabBarItem(label: 'Home', icon: CNSymbol('house.fill')),
        CNTabBarItem(label: 'Search', icon: CNSymbol('magnifyingglass')),
        CNTabBarItem(label: 'Messages', icon: CNSymbol('bubble.left.and.bubble.right.fill')),
        CNTabBarItem(label: 'Trips', icon: CNSymbol('suitcase.fill')),
        CNTabBarItem(label: 'Profile', icon: CNSymbol('person.crop.circle.fill')),
      ],
    );
  }
}
