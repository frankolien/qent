import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/core/widgets/profile_image_widget.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart';
import 'package:qent/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:qent/main.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;
    final userId = user?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const SizedBox.shrink(), // No back button since it's in bottom nav
        title: const Text(
          'Profile',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        actions: [
          GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.more_vert, size: 20, color: Colors.black),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 24),
              _buildProfileHeader(context, ref, userId),
              const SizedBox(height: 32),
              _buildGeneralSection(context),
              const SizedBox(height: 24),
              _buildSupportSection(context, ref),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, WidgetRef ref, String? userId) {
    final authState = ref.watch(authControllerProvider);
    final currentUserId = userId ?? authState.user?.uid;

    if (currentUserId == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder(
      future: ref.read(userProfileRepositoryProvider).getUserProfile(currentUserId),
      builder: (context, snapshot) {
        String firstName = 'User';
        
        if (snapshot.hasData && snapshot.data != null) {
          final fullName = snapshot.data!.fullName;
          final nameParts = fullName.split(' ');
          firstName = nameParts.isNotEmpty ? nameParts.first : fullName;
        } else if (snapshot.connectionState == ConnectionState.waiting) {
          firstName = 'Loading...';
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Profile Picture with Camera Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey[200]!, width: 2),
                ),
                child: ProfileImageWidget(
                  userId: currentUserId,
                  size: 80,
                  showEditIcon: true,
                  onEditTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EditProfilePage(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      firstName,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Icon(Icons.edit, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EditProfilePage(),
                        ),
                      );
                    },
                    child: Text(
                      'Edit profile',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGeneralSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: const Text(
            'General',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildMenuItem(
          context: context,
          icon: Icons.favorite,
          title: 'Favorite Cars',
          onTap: () {
            // TODO: Navigate to favorite cars screen
          },
        ),
        _buildMenuItem(
          context: context,
          icon: Icons.access_time,
          title: 'Previous Rant',
          onTap: () {
            // TODO: Navigate to previous rentals screen
          },
        ),
        _buildMenuItem(
          context: context,
          icon: Icons.notifications_outlined,
          title: 'Notification',
          onTap: () {
            // TODO: Navigate to notification settings
          },
        ),
        _buildMenuItem(
          context: context,
          icon: Icons.link,
          title: 'Connected to QENT Partnerships',
          onTap: () {
            // TODO: Navigate to partnerships screen
          },
        ),
      ],
    );
  }

  Widget _buildSupportSection(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: const Text(
            'Support',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildMenuItem(
          context: context,
          icon: Icons.settings,
          title: 'Settings',
          onTap: () {
            // TODO: Navigate to settings screen
          },
        ),
        _buildMenuItem(
          context: context,
          icon: Icons.language,
          title: 'Languages',
          onTap: () {
            // TODO: Navigate to language selection screen
          },
        ),
        _buildMenuItem(
          context: context,
          icon: Icons.person_add,
          title: 'Invite Friends',
          onTap: () {
            // TODO: Implement invite friends functionality
          },
        ),
        _buildMenuItem(
          context: context,
          icon: Icons.privacy_tip,
          title: 'privacy policy',
          onTap: () {
            // TODO: Navigate to privacy policy screen
          },
        ),
        _buildMenuItem(
          context: context,
          icon: Icons.headset_mic,
          title: 'Help Support',
          onTap: () {
            // TODO: Navigate to help support screen
          },
        ),
        _buildMenuItem(
          context: context,
          icon: Icons.logout,
          title: 'Log out',
          onTap: () {
            _showLogoutDialog(context, ref);
          },
          isDestructive: true,
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isDestructive ? Colors.red : Colors.black87,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDestructive ? Colors.red : Colors.black87,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Log out'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                // Sign out - MainApp will handle navigation automatically via auth state
                await ref.read(authControllerProvider.notifier).signOut();
            
              },
              child: const Text(
                'Log out',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
}

