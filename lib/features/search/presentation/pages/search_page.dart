import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/features/home/domain/models/car.dart';
import 'package:qent/features/search/domain/models/filter_options.dart';
import 'package:qent/features/search/presentation/providers/search_providers.dart';
import 'package:qent/features/search/presentation/widgets/filter_bottom_sheet.dart';
import 'package:qent/features/search/presentation/widgets/search_car_card.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _searchController = TextEditingController();

  final List<Car> _recommendedCars = [
    Car(
      id: '1',
      name: 'Tesla Model S',
      brand: 'Tesla',
      imageUrl: 'assets/images/tesla_model_s.png',
      rating: 5.0,
      location: 'Chicago, USA',
      seats: 5,
      pricePerDay: 100,
    ),
    Car(
      id: '2',
      name: 'Ferrari LaFerrari',
      brand: 'Ferrari',
      imageUrl: 'assets/images/ferrari_laf.png',
      rating: 5.0,
      location: 'Washington DC',
      seats: 2,
      pricePerDay: 100,
    ),
    Car(
      id: '3',
      name: 'Lamborghini Aventador',
      brand: 'Lamborghini',
      imageUrl: 'assets/images/lambo_car.png',
      rating: 4.9,
      location: 'Washington DC',
      seats: 2,
      pricePerDay: 100,
    ),
    Car(
      id: '4',
      name: 'BMW GTS3 M2',
      brand: 'BMW',
      imageUrl: 'assets/images/Bmw.png',
      rating: 5.0,
      location: 'New York, USA',
      seats: 4,
      pricePerDay: 100,
    ),
  ];

  final List<Car> _popularCars = [
    Car(
      id: '5',
      name: 'Ferrari LaFerrari',
      brand: 'Ferrari',
      imageUrl: 'assets/images/ferrari_ff.png',
      rating: 5.0,
      location: 'Los Angeles, USA',
      seats: 2,
      pricePerDay: 100,
    ),
    Car(
      id: '6',
      name: 'BMW M4',
      brand: 'BMW',
      imageUrl: 'assets/images/bmw_m4.png',
      rating: 4.8,
      location: 'Miami, USA',
      seats: 4,
      pricePerDay: 150,
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filterOptionsState = ref.watch(filterOptionsControllerProvider);
    final screenHeight = MediaQuery.of(context).size.height;
    final cardHeight = screenHeight * 0.32;

    // Update search query when controller changes
    _searchController.addListener(() {
      ref.read(searchControllerProvider.notifier).updateSearchQuery(
        _searchController.text,
      );
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildSearchBar(context),
            const SizedBox(height: 16),
            _buildBrandFilters(context, filterOptionsState.options.brandFilters),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRecommendedSection(context, cardHeight),
                    SizedBox(height: screenHeight * 0.04),
                    _buildPopularSection(context, cardHeight),
                    SizedBox(height: screenHeight * 0.1),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.04,
        vertical: 16,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 40), // Spacer for alignment
          const Text(
            'Search',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
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
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Icon(Icons.search, color: Colors.grey[600], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search your dream car.....',
                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
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
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.tune, size: 20, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandFilters(BuildContext context, List<BrandFilter> brandFilters) {
    final screenWidth = MediaQuery.of(context).size.width;
    final searchState = ref.watch(searchControllerProvider);
    final selectedFilter = searchState.filters.selectedBrandFilter;
    
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
        itemCount: brandFilters.length,
        itemBuilder: (context, index) {
          final filter = brandFilters[index];
          final isSelected = selectedFilter == filter.name;
          
          return Padding(
            padding: EdgeInsets.only(
              right: index < brandFilters.length - 1 ? 16 : 0,
            ),
            child: GestureDetector(
              onTap: () {
                ref.read(searchControllerProvider.notifier).updateBrandFilter(filter.name);
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: filter.name == 'ALL' ? 16 : 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF2C2C2C) : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (filter.name == 'ALL')
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.grey[300],
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.dehaze,
                            color: isSelected ? Colors.black : Colors.grey[600],
                            size: 16,
                          ),
                        ),
                      ),
                    if (filter.name == 'ALL') const SizedBox(width: 8),
                    if (filter.name != 'ALL')
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: _getBrandLogo(filter),
                        ),
                      ),
                    if (filter.name != 'ALL') const SizedBox(width: 8),
                    if (filter.name != 'Lamborghini')
                      Text(
                        filter.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : Colors.grey[700],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _getBrandLogo(BrandFilter filter) {
    if (filter.logoUrl == null) {
      return const Icon(Icons.directions_car, color: Colors.white, size: 20);
    }
    
    return Image.asset(
      filter.logoUrl!,
      width: 20,
      height: 20,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return const Icon(Icons.directions_car, color: Colors.white, size: 20);
      },
    );
  }

  Widget _buildRecommendedSection(BuildContext context, double cardHeight) {
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
                'Recommend For You',
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
        SizedBox(
          height: cardHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
            itemCount: _recommendedCars.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index < _recommendedCars.length - 1 ? screenWidth * 0.04 : 0,
                ),
                child: SearchCarCard(
                  car: _recommendedCars[index],
                  onFavoriteTap: () {
                    // TODO: Implement favorite toggle with Riverpod
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPopularSection(BuildContext context, double cardHeight) {
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
                'Our Popular Cars',
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
        SizedBox(
          height: cardHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
            itemCount: _popularCars.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index < _popularCars.length - 1 ? screenWidth * 0.04 : 0,
                ),
                child: SearchCarCard(
                  car: _popularCars[index],
                  onFavoriteTap: () {
                    // TODO: Implement favorite toggle with Riverpod
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

