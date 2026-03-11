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
import 'package:qent/features/home/presentation/pages/view_all_cars_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  String _selectedBrand = 'All';

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
    final carsAsync = ref.watch(carsProvider);
    final authState = ref.watch(authControllerProvider);
    final userId = authState.user?.uid ?? '';
    final carController = ref.read(carControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: SafeArea(
        child: CarPullToRefresh(
          onRefresh: () async {
            ref.invalidate(carsProvider);
            await ref.read(carsProvider.future);
          },
          child: CustomScrollView(
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
              // White content area
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        _buildBestCarsSection(context, carsAsync, userId, carController),
                        const SizedBox(height: 28),
                        _buildNearbySection(context, carsAsync, userId, carController),
                        const SizedBox(height: 100),
                      ],
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

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Image.asset(
                  'assets/images/image_logo.png',
                  width: 24,
                  height: 24,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.directions_car,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Qent',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          Row(
            children: [
              _buildIconButton(
                icon: Icons.notifications_none_rounded,
                badgeCount: 2,
                onTap: () {},
              ),
              const SizedBox(width: 8),
              _buildIconButton(
                icon: Icons.person_outline_rounded,
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    int badgeCount = 0,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 22, color: const Color(0xFF1A1A1A)),
            if (badgeCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF3B30),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
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

  Widget _buildSearchBar(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(Icons.search_rounded, color: Colors.grey[400], size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search cars...',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
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

  Widget _buildBestCarsSection(BuildContext context, AsyncValue<List<Car>> carsAsync, String userId, CarController carController) {
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
                  const Text(
                    'Best Cars',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Top rated vehicles',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  final cars = carsAsync.value ?? [];
                  var bestCars = cars.where((car) => car.rating >= 4.5).toList();
                  if (_selectedBrand != 'All') {
                    bestCars = bestCars.where((car) =>
                      car.brand.toLowerCase().contains(_selectedBrand.toLowerCase())).toList();
                  }
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ViewAllCarsPage(title: 'Best Cars', cars: bestCars),
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
          height: 230,
          child: _buildBestCarsList(context, carsAsync, userId, carController),
        ),
      ],
    );
  }

  Widget _buildNearbySection(BuildContext context, AsyncValue<List<Car>> carsAsync, String userId, CarController carController) {
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
                  const Text(
                    'Nearby',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Cars around you',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  final cars = carsAsync.value ?? [];
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ViewAllCarsPage(title: 'Nearby Cars', cars: cars),
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
        _buildNearbyList(context, carsAsync, userId, carController),
      ],
    );
  }

  Widget _buildBestCarsList(BuildContext context, AsyncValue<List<Car>> carsAsync, String userId, CarController carController) {
    return carsAsync.when(
      data: (cars) {
        var filteredCars = cars.where((car) => car.rating >= 4.5);
        if (_selectedBrand != 'All') {
          filteredCars = filteredCars.where((car) =>
            car.brand.toLowerCase().contains(_selectedBrand.toLowerCase()));
        }
        final bestCars = filteredCars.take(10).toList();

        if (bestCars.isEmpty) {
          return Center(
            child: Text(
              'No cars found',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
          );
        }

        return ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: bestCars.length,
          itemBuilder: (context, index) {
            return StaggeredFadeIn(
              index: index,
              child: Padding(
                padding: EdgeInsets.only(right: index < bestCars.length - 1 ? 14 : 0),
                child: CarCard(
                  car: bestCars[index],
                  onFavoriteTap: () {
                    if (userId.isNotEmpty) {
                      carController.toggleFavorite(bestCars[index].id);
                    }
                  },
                ),
              ),
            );
          },
        );
      },
      loading: () => ListView.builder(
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
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 40, color: Colors.grey[300]),
            const SizedBox(height: 8),
            Text('Failed to load', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => ref.invalidate(carsProvider),
              child: const Text('Retry', style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNearbyList(BuildContext context, AsyncValue<List<Car>> carsAsync, String userId, CarController carController) {
    return carsAsync.when(
      data: (cars) {
        if (cars.isEmpty) return const SizedBox.shrink();

        // Show up to 3 nearby cars
        final nearbyCars = cars.take(3).toList();

        return Column(
          children: nearbyCars.asMap().entries.map((entry) {
            final index = entry.key;
            final car = entry.value;
            return StaggeredFadeIn(
              index: index,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: NearbyCarCard(
                  car: car,
                  onFavoriteTap: () {
                    if (userId.isNotEmpty) {
                      carController.toggleFavorite(car.id);
                    }
                  },
                ),
              ),
            );
          }).toList(),
        );
      },
      loading: () => Column(
        children: List.generate(2, (index) => const Padding(
          padding: EdgeInsets.only(bottom: 14),
          child: NearbyCardSkeleton(),
        )),
      ),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }
}
