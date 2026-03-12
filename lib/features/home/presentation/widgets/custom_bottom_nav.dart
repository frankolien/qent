import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart';

class CustomBottomNav extends ConsumerWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _navItems = [
    _NavItemData('assets/images/navbar/home.png', 0),
    _NavItemData('assets/images/navbar/search.png', 1),
    _NavItemData('assets/images/navbar/message.png', 2),
    _NavItemData('assets/images/navbar/notification.png', 3),
    _NavItemData('assets/images/navbar/profile.png', 4),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final photoUrl = authState.user?.profilePhotoUrl;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding + 8),
      child: Container(
      height: 70,
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(60),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _navItems.map((item) {
          final isSelected = currentIndex == item.index;
          if (item.index == 4) {
            return _buildProfileItem(
              photoUrl: photoUrl,
              isSelected: isSelected,
              onTap: () => onTap(item.index),
              fallbackAsset: item.assetPath,
            );
          }
          return _buildNavItem(
            assetPath: item.assetPath,
            isSelected: isSelected,
            onTap: () => onTap(item.index),
          );
        }).toList(),
      ),
    ),
    );
  }

  Widget _buildNavItem({
    required String assetPath,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 52,
        height: 52,
        child: Center(
          child: Image.asset(
            assetPath,
            width: 26,
            height: 26,
            color: isSelected ? Colors.white : Colors.grey[500],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileItem({
    required String? photoUrl,
    required bool isSelected,
    required VoidCallback onTap,
    required String fallbackAsset,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 52,
        height: 52,
        child: Center(
          child: photoUrl != null && photoUrl.isNotEmpty
              ? Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Image.asset(
                        fallbackAsset,
                        width: 26,
                        height: 26,
                        color: isSelected ? Colors.white : Colors.grey[500],
                      ),
                    ),
                  ),
                )
              : Image.asset(
                  fallbackAsset,
                  width: 26,
                  height: 26,
                  color: isSelected ? Colors.white : Colors.grey[500],
                ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final String assetPath;
  final int index;

  const _NavItemData(this.assetPath, this.index);
}
