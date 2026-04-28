import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/core/widgets/animated_loading.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart';
import 'package:qent/features/home/presentation/providers/car_providers.dart';
import 'package:qent/features/home/domain/models/car.dart';
import 'package:qent/features/home/presentation/widgets/brand_item.dart';
import 'package:qent/features/home/presentation/widgets/car_card.dart';
import 'package:qent/features/home/presentation/widgets/nearby_car_card.dart';
import 'package:qent/features/home/presentation/widgets/car_card_skeleton.dart';
import 'package:qent/features/search/presentation/widgets/filter_bottom_sheet.dart';
import 'package:qent/features/home/presentation/pages/main_nav_page.dart';
import 'package:qent/features/home/presentation/pages/view_all_cars_page.dart';
import 'package:qent/features/home/presentation/providers/location_provider.dart';
import 'package:qent/features/home/presentation/widgets/location_picker_sheet.dart';
import 'package:qent/features/profile/presentation/pages/profile_page.dart';
import 'package:qent/features/notifications/presentation/pages/notifications_page.dart';
import 'package:qent/features/notifications/presentation/providers/notification_providers.dart';
import 'package:qent/core/theme/app_theme.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  static final globalKey = GlobalKey<HomePageState>();

  @override
  ConsumerState<HomePage> createState() => HomePageState();
}

class HomePageState extends ConsumerState<HomePage> {
  String _selectedBrand = 'All';
  final ScrollController _scrollController = ScrollController();

  void scrollToTopAndRefresh() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
    _invalidateHomepage();
  }

  void _invalidateHomepage() {
    final loc = ref.read(userLocationProvider).value;
    ref.invalidate(homepageCarsProvider((lat: loc?.latitude, lng: loc?.longitude)));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  final List<String> _brands = [
    'All',
    'Toyota',
    'Honda',
    'Mercedes',
    'Lexus',
    'Range Rover',
  ];

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(userLocationProvider).value;
    final homepageAsync = ref.watch(
      homepageCarsProvider((lat: loc?.latitude, lng: loc?.longitude)),
    );
    final authState = ref.watch(authControllerProvider);
    final userId = authState.user?.uid ?? '';

    return Scaffold(
      backgroundColor: context.bgPrimary,
      body: SafeArea(
        bottom: true,
        child: CarPullToRefresh(
          onRefresh: () async {
            _invalidateHomepage();
            final loc = ref.read(userLocationProvider).value;
            await ref.read(
              homepageCarsProvider((lat: loc?.latitude, lng: loc?.longitude)).future,
            );
          },
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              // App bar
              SliverToBoxAdapter(child: _buildAppBar(context)),
              // Search bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: _buildSearchBar(context),
                ),
              ),
              // Brands
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: _buildBrandsSection(context),
                ),
              ),
              // White content area with all sections
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.bgPrimary,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    child: homepageAsync.when(
                      data: (sections) {
                        final recommended = _filterByBrand(sections['recommended'] ?? []);
                        final bestCars = _filterByBrand(sections['best_cars'] ?? []);
                        final nearby = _filterByBrand(sections['nearby'] ?? []);
                        final popular = _filterByBrand(sections['popular'] ?? []);

                        return Column(
                          children: [
                            //const SizedBox(height: 5),
                            if (recommended.isNotEmpty)
                              _buildHorizontalSection(
                                context,
                                title: 'Recommended for You',
                                subtitle: 'Based on your preferences',
                                cars: recommended,
                                userId: userId,
                              ),
                            if (bestCars.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              _buildHorizontalSection(
                                context,
                                title: 'Best Cars',
                                subtitle: 'Top rated vehicles',
                                cars: bestCars,
                                userId: userId,
                              ),
                            ],
                            if (popular.isNotEmpty) ...[
                              const SizedBox(height: 28),
                              _buildHorizontalSection(
                                context,
                                title: 'Our Popular Cars',
                                subtitle: 'Most booked on Qent',
                                cars: popular,
                                userId: userId,
                              ),
                            ],
                            const SizedBox(height: 28),
                            _buildVerticalSection(
                              context,
                              title: 'Nearby',
                              subtitle: 'Cars around you',
                              cars: nearby,
                              userId: userId,
                            ),
                            const SizedBox(height: 100),
                          ],
                        );
                      },
                      loading: () => Column(
                        children: [
                          const SizedBox(height: 24),
                          _buildSkeletonHorizontalSection('Recommended for You'),
                          const SizedBox(height: 28),
                          _buildSkeletonHorizontalSection('Best Cars'),
                          const SizedBox(height: 28),
                          _buildSkeletonVerticalSection('Nearby'),
                          const SizedBox(height: 100),
                        ],
                      ),
                      error: (error, stack) => Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            Icon(Icons.wifi_off_rounded, size: 40, color: Colors.grey[300]),
                            const SizedBox(height: 8),
                            Text('Failed to load', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: _invalidateHomepage,
                              child: const Text('Retry', style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w600, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Car> _filterByBrand(List<Car> cars) {
    if (_selectedBrand == 'All') return cars;
    return cars.where((car) => car.brand.toLowerCase().contains(_selectedBrand.toLowerCase())).toList();
  }

  Widget _buildAppBar(BuildContext context) {
    final locationAsync = ref.watch(userLocationProvider);
    final notificationsAsync = ref.watch(notificationsProvider);
    final unreadCount = notificationsAsync.maybeWhen(
      data: (list) => list.where((n) => !n.isRead).length,
      orElse: () => 0,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const LocationPickerSheet(),
              );
            },
            child: Row(
              children: [
                Icon(Icons.location_on, size: 20, color: context.textPrimary),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your location',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: context.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        locationAsync.when(
                          data: (loc) => Text(
                            '${loc.city ?? loc.name}, ${loc.country ?? 'Nigeria'}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: context.textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                          loading: () => const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF1A1A1A)),
                          ),
                          error: (_, __) => Text(
                            'Lagos, Nigeria',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: context.textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.grey[600]),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              _buildNotificationButton(
                context: context,
                badgeCount: unreadCount,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationsPage(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              _buildProfileAvatar(context, ref),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationButton({
    required BuildContext context,
    int badgeCount = 0,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 42,
        height: 42,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Image.asset(
              'assets/images/Notifications.png',
              width: 42,
              height: 42,
              fit: BoxFit.contain,
              color: context.isDark ? Colors.white : null,
            ),
            if (badgeCount > 0)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.bgPrimary, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileAvatar(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final photoUrl = authState.user?.profilePhotoUrl;

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()));
      },
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: context.bgSecondary,
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: photoUrl != null && photoUrl.isNotEmpty
              ? Image.network(
                  photoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Icon(Icons.person_outline_rounded, size: 22, color: context.textPrimary),
                )
              : Icon(Icons.person_outline_rounded, size: 22, color: context.textPrimary),
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: context.bgPrimary,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderColor),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(Icons.search_rounded, color: Colors.grey[400], size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      MainNavPage.globalKey.currentState?.switchToTab(1);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        'Search cars...',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const FilterBottomSheet(),
            );
          },
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.tune_rounded, size: 20, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildBrandsSection(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _brands.length,
        itemBuilder: (context, index) {
          final brand = _brands[index];
          return BrandItem(
            brand: brand,
            isSelected: _selectedBrand == brand,
            onTap: () {
              setState(() => _selectedBrand = brand);
            },
          );
        },
      ),
    );
  }

  // ─── Reusable section builders ─────────────────────────────────

  /// Horizontal scrolling car section (for Recommended, Best Cars, Popular)
  Widget _buildHorizontalSection(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<Car> cars,
    required String userId,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: context.isDark ? context.accent : context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ViewAllCarsPage(title: title, cars: cars),
                  ));
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[400],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: cars.length,
            itemBuilder: (context, index) {
              return StaggeredFadeIn(
                index: index,
                child: Padding(
                  padding: EdgeInsets.only(right: index < cars.length - 1 ? 14 : 0),
                  child: Consumer(
                    builder: (context, ref, _) {
                      final favIds = ref.watch(favoriteIdsProvider);
                      final car = cars[index];
                      return CarCard(
                        car: car.copyWith(isFavorite: favIds.contains(car.id)),
                        onFavoriteTap: () {
                          if (userId.isNotEmpty) {
                            ref.read(favoriteIdsProvider.notifier).toggle(car.id);
                          }
                        },
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Vertical list section (for Nearby)
  Widget _buildVerticalSection(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<Car> cars,
    required String userId,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: context.isDark ? context.accent : context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ViewAllCarsPage(title: title, cars: cars),
                  ));
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[400],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (cars.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Center(
              child: Text(
                'No cars found nearby',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
            ),
          )
        else
          ...cars.take(5).toList().asMap().entries.map((entry) {
            final index = entry.key;
            final car = entry.value;
            return StaggeredFadeIn(
              index: index,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Consumer(
                  builder: (context, ref, _) {
                    final favIds = ref.watch(favoriteIdsProvider);
                    return NearbyCarCard(
                      car: car.copyWith(isFavorite: favIds.contains(car.id)),
                      onFavoriteTap: () {
                        if (userId.isNotEmpty) {
                          ref.read(favoriteIdsProvider.notifier).toggle(car.id);
                        }
                      },
                    );
                  },
                ),
              ),
            );
          }),
      ],
    );
  }

  // ─── Skeleton loading states ─────────────────────────────────

  Widget _buildSkeletonHorizontalSection(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: 3,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(right: index < 2 ? 14 : 0),
                child: const CarCardSkeleton(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonVerticalSection(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Column(
          children: List.generate(2, (index) => const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: NearbyCardSkeleton(),
          )),
        ),
      ],
    );
  }
}
