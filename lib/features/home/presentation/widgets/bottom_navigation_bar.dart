import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart';

class CustomBottomNavigationBar extends ConsumerWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final photoUrl = authState.user?.profilePhotoUrl;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(16),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey[400],
        items: [
          BottomNavigationBarItem(
            icon: Icon(
              currentIndex == 0 ? Icons.home : Icons.home_outlined,
              size: 24,
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              currentIndex == 1 ? Icons.search : Icons.search_outlined,
              size: 24,
            ),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              currentIndex == 2 ? Icons.email : Icons.email_outlined,
              size: 24,
            ),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              currentIndex == 3 ? Icons.notifications : Icons.notifications_outlined,
              size: 24,
            ),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(
            icon: _buildProfileIcon(photoUrl),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildProfileIcon(String? photoUrl) {
    final isSelected = currentIndex == 4;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2,
          ),
        ),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: photoUrl,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => Icon(
              isSelected ? Icons.person : Icons.person_outline,
              size: 20,
              color: isSelected ? Colors.white : Colors.grey[400],
            ),
          ),
        ),
      );
    }
    return Icon(
      isSelected ? Icons.person : Icons.person_outline,
      size: 24,
      color: isSelected ? Colors.white : Colors.grey[400],
    );
  }
}
