import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qent/core/widgets/profile_image_widget.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart';
import 'package:qent/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:qent/features/favorites/presentation/pages/favorites_page.dart';
import 'package:qent/features/dashboard/presentation/pages/host_dashboard_page.dart';
import 'package:qent/features/dashboard/presentation/pages/add_listing_page.dart';
import 'package:qent/features/booking/presentation/pages/booking_history_page.dart';
import 'package:qent/features/notifications/presentation/pages/notifications_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qent/features/admin/presentation/pages/admin_panel_page.dart';
import 'package:qent/core/providers/theme_provider.dart';
import 'package:qent/core/theme/app_theme.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;
    final userId = user?.uid;

    return Scaffold(
      backgroundColor: context.bgPrimary,
      appBar: AppBar(
        backgroundColor: context.bgPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,

        centerTitle: true,
        title: Text(
          'Profile',
          style: GoogleFonts.roboto(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
          ),
        ),

        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: context.borderColor, height: 1),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              _buildProfileHeader(context, ref, userId),
              const SizedBox(height: 32),
              if (user?.role == 'Admin') ...[
                _buildSectionTitle('Admin'),
                const SizedBox(height: 12),
                _buildMenuItemIcon(
                  Icons.admin_panel_settings_outlined,
                  'Admin Panel',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanelPage())),
                ),
                const SizedBox(height: 28),
              ],
              if (user?.role == 'Host' || user?.role == 'Admin') ...[
                _buildSectionTitle('Host'),
                const SizedBox(height: 12),
                _buildMenuItemIcon(
                  Icons.dashboard_outlined,
                  'Dashboard',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HostDashboardPage())),
                ),
                _buildMenuItemIcon(
                  Icons.add_circle_outline,
                  'Add New Listing',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddListingPage())),
                ),
                const SizedBox(height: 28),
              ],
              _buildSectionTitle('General'),
              const SizedBox(height: 12),
              _buildMenuItem(
                'assets/images/Profile/heart.png',
                'Favorite Cars',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesPage())),
              ),
              _buildMenuItem(
                'assets/images/Profile/time.png',
                'Booking History',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BookingHistoryPage())),
              ),
              _buildMenuItem(
                'assets/images/Profile/notification.png',
                'Notification',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsPage()),
                ),
              ),
              _buildDarkModeToggle(ref),
              _buildMenuItem(
                'assets/images/Profile/connect.png',
                'Connected to QENT Partnerships',
                onTap: () => Navigator.of(context).pushNamed('/partner/onboarding'),
              ),
              const SizedBox(height: 28),
              _buildSectionTitle('Support'),
              const SizedBox(height: 12),
              _buildMenuItem(
                'assets/images/Profile/settings.png',
                'Settings',
                onTap: () => _showComingSoon(context, 'Settings'),
              ),
              _buildMenuItem(
                'assets/images/Profile/language.png',
                'Languages',
                onTap: () => _showComingSoon(context, 'Languages'),
              ),
              _buildMenuItem(
                'assets/images/Profile/invite_friend.png',
                'Invite Friends',
                onTap: () => _showComingSoon(context, 'Invite Friends'),
              ),
              _buildMenuItem(
                'assets/images/Profile/privacy.png',
                'Privacy Policy',
                onTap: () => _openUrl(context, 'https://qent.online/privacy'),
              ),
              _buildMenuItem(
                'assets/images/Profile/support.png',
                'Help & Support',
                onTap: () => _openUrl(context, 'mailto:support@qent.online'),
              ),
              _buildMenuItem(
                'assets/images/Profile/log_out.png',
                'Log out',
                onTap: () => _showLogoutDialog(context, ref),
              ),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, WidgetRef ref, String? userId) {
    final authState = ref.watch(authControllerProvider);
    final fullName = authState.user?.fullName ?? 'User';
    final email = authState.user?.email ?? '';
    final currentUserId = userId ?? authState.user?.uid;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Profile photo with camera icon
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey[200]!, width: 2),
                ),
                child: ProfileImageWidget(
                  userId: currentUserId ?? '',
                  imageUrl: authState.user?.profilePhotoUrl,
                  size: 72,
                  showEditIcon: false,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt, size: 13, color: Colors.black54),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          // Name and email
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: GoogleFonts.roboto(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  style: GoogleFonts.roboto(
                    fontSize: 13,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Edit profile button
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfilePage()));
            },
            child: Column(
              children: [
                Icon(Icons.edit_outlined, size: 18, color: Colors.grey[600]),
                const SizedBox(height: 2),
                Text(
                  'Edit profile',
                  style: GoogleFonts.roboto(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Builder(builder: (context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title,
        style: GoogleFonts.roboto(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: context.textPrimary,
        ),
      ),
    ));
  }

  Widget _buildMenuItem(String assetPath, String title, {required VoidCallback onTap}) {
    return Builder(builder: (context) => GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Center(
              child: Image.asset(
                assetPath,
                width: 20,
                height: 20,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.roboto(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: context.textPrimary,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 22, color: context.textTertiary),
          ],
        ),
      ),
    ));
  }

  Widget _buildDarkModeToggle(WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final (icon, label) = switch (mode) {
      ThemeMode.system => (Icons.brightness_auto_rounded, 'System'),
      ThemeMode.light => (Icons.light_mode_rounded, 'Light'),
      ThemeMode.dark => (Icons.dark_mode_rounded, 'Dark'),
    };
    return Builder(builder: (context) => InkWell(
      onTap: () => ref.read(themeModeProvider.notifier).cycle(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: context.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Appearance',
                style: GoogleFonts.roboto(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: context.textPrimary,
                ),
              ),
            ),
            Text(
              label,
              style: GoogleFonts.roboto(
                fontSize: 14,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, size: 20, color: context.textSecondary),
          ],
        ),
      ),
    ));
  }

  Widget _buildMenuItemIcon(IconData icon, String title, {required VoidCallback onTap}) {
    return Builder(builder: (context) => GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: context.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.roboto(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: context.textPrimary,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 22, color: context.textTertiary),
          ],
        ),
      ),
    ));
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature is coming soon'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $url')),
      );
    }
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.logout_rounded, color: Colors.red, size: 28),
                ),
                const SizedBox(height: 16),
                Text(
                  'Log Out',
                  style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.w700, color: context.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Are you sure you want to log out?',
                  style: GoogleFonts.roboto(fontSize: 14, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.of(dialogContext).pop(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: context.bgSecondary,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.roboto(fontSize: 15, fontWeight: FontWeight.w600, color: context.textPrimary),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          Navigator.of(dialogContext).pop();
                          await ref.read(authControllerProvider.notifier).signOut();
                          if (context.mounted) {
                            Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              'Log Out',
                              style: GoogleFonts.roboto(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
