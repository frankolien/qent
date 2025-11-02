import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/core/providers/user_cache_provider.dart';

class ProfileImageWidget extends ConsumerWidget {
  final String? userId;
  final String? imageUrl; // Optional direct URL override
  final double size;
  final bool showEditIcon;
  final VoidCallback? onEditTap;

  const ProfileImageWidget({
    super.key,
    this.userId,
    this.imageUrl,
    this.size = 56,
    this.showEditIcon = false,
    this.onEditTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If direct URL is provided, use it
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return _buildImageWithUrl(imageUrl!);
    }

    // If userId is provided, use cached stream provider for better performance
    if (userId != null && userId!.isNotEmpty) {
      final userDataAsync = ref.watch(userDataStreamProvider(userId!));
      
      return userDataAsync.when(
        data: (userData) {
          if (userData != null) {
            final profileImageUrl = userData['profileImageUrl'] as String?;
            if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
              return _buildImageWithUrl(profileImageUrl);
            }
          }
          return _buildPlaceholder();
        },
        loading: () => _buildPlaceholder(),
        error: (_, __) => _buildPlaceholder(),
      );
    }

    // Default placeholder
    return _buildPlaceholder();
  }

  Widget _buildImageWithUrl(String url) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey[300],
          ),
          child: ClipOval(
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildPlaceholderIcon();
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              },
            ),
          ),
        ),
        if (showEditIcon && onEditTap != null)
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: onEditTap,
              child: Container(
                width: size * 0.32,
                height: size * 0.32,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(
                  Icons.edit,
                  size: size * 0.16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey[300],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/profile_placeholder.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildPlaceholderIcon();
              },
            ),
          ),
        ),
        if (showEditIcon && onEditTap != null)
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: onEditTap,
              child: Container(
                width: size * 0.32,
                height: size * 0.32,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(
                  Icons.edit,
                  size: size * 0.16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPlaceholderIcon() {
    return Container(
      color: Colors.grey[300],
      child: Icon(
        Icons.person,
        size: size * 0.5,
        color: Colors.grey,
      ),
    );
  }
}

