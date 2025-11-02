import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart';
import 'package:qent/features/home/presentation/providers/car_providers.dart';
import 'package:qent/features/home/presentation/widgets/brand_item.dart';
import 'package:qent/features/home/presentation/widgets/car_card.dart';
import 'package:qent/features/home/presentation/widgets/nearby_car_card.dart';
import 'package:qent/features/search/presentation/widgets/filter_bottom_sheet.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final List<String> _brands = [
    'Tesla',
    'Lamborghini',
    'BMW',
    'Ferrari',
  ];

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      backgroundColor: Color(0xFFF8F8F8),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            SizedBox(height: screenHeight * 0.025),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSearchBar(context),
                    SizedBox(height: screenHeight * 0.025),
                    _buildBrandsSection(context),
                    SizedBox(height: screenHeight * 0.050),
                    Container(
                      
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(topLeft: Radius.circular(40), topRight: Radius.circular(40)),
                      ),
                      child: Column(
                        children: [
                          _buildBestCarsSection(context),
                          SizedBox(height: screenHeight * 0.025),
                          _buildNearbySection(context),
                        ],
                      )
                      ),
                    /*SizedBox(height: screenHeight * 0.025),
                    _buildNearbySection(context),*/
                    SizedBox(height: screenHeight * 0.1), // Space for bottom nav
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Padding(
      padding: EdgeInsets.fromLTRB(
        screenWidth * 0.04,
        MediaQuery.of(context).size.height * 0.02,
        screenWidth * 0.04,
        MediaQuery.of(context).size.height * 0.015,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            child: Image.asset(
              'assets/images/image_logo.png',
              width: 30,
              height: 30,
            ),
          ),
              SizedBox(width: screenWidth * 0.025),
              const Text(
            'Qent',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
            ],
          ),
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded, size: 26),
                    onPressed: () {},
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          '2',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(width: screenWidth * 0.025),
              Container(
                width: 40,
                height: 40,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                child: ClipOval(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {},
                      child: const Icon(Icons.person, size: 22, color: Colors.black),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
      child: Row(
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 50),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Icon(Icons.search, color: Colors.grey[600], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search your dream car.....',
                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                        fillColor: Colors.white,
                        filled: true,
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
          SizedBox(width: screenWidth * 0.03),
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
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                //borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.tune, size: 20, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandsSection(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
          child: const Text(
            'Brands',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 70,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
            itemCount: _brands.length,
            itemBuilder: (context, index) {
              return BrandItem(brand: _brands[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBestCarsSection(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardHeight = MediaQuery.of(context).size.height * 0.28;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children:  [
                  Text(
                    'Best Cars',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 4),
                    TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                
                  'View All',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
                  
                ],
              ),
            
              Text(  
                    'Available',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: cardHeight,
          child: _buildBestCarsList(context, screenWidth),
        ),
      ],
    );
  }

  Widget _buildNearbySection(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Nearby',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildNearbyCar(context),
      ],
    );
  }

  Widget _buildBestCarsList(BuildContext context, double screenWidth) {
    final carsAsync = ref.watch(carsStreamProvider);

    return carsAsync.when(
      data: (cars) {
        // Filter best cars (high rating)
        final bestCars = cars.where((car) => car.rating >= 4.5).take(10).toList();

        if (bestCars.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                'No cars available',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          );
        }

        return ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
          itemCount: bestCars.length,
          itemBuilder: (context, index) {
            final car = bestCars[index];
            final auth = ref.read(firebaseAuthProvider);
            final userId = auth.currentUser?.uid ?? '';

            return Padding(
              padding: EdgeInsets.only(
                right: index < bestCars.length - 1 ? screenWidth * 0.04 : 0,
              ),
              child: CarCard(
                car: car,
                onFavoriteTap: () {
                  if (userId.isNotEmpty) {
                    ref.read(carControllerProvider).toggleFavorite(
                      userId,
                      car.id,
                      !car.isFavorite,
                    );
                  }
                },
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Error loading cars',
              style: TextStyle(color: Colors.red[600]),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => ref.invalidate(carsStreamProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNearbyCar(BuildContext context) {
    final carsAsync = ref.watch(carsStreamProvider);

    return carsAsync.when(
      data: (cars) {
        if (cars.isEmpty) {
          return const SizedBox.shrink();
        }

        // Get first car as nearby (in real app, filter by location)
        final nearbyCar = cars.first;
        final auth = ref.read(firebaseAuthProvider);
        final userId = auth.currentUser?.uid ?? '';

        return NearbyCarCard(
          car: nearbyCar,
          onFavoriteTap: () {
            if (userId.isNotEmpty) {
              ref.read(carControllerProvider).toggleFavorite(
                userId,
                nearbyCar.id,
                !nearbyCar.isFavorite,
              );
            }
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }
}