import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart';
import 'package:qent/features/home/domain/models/car.dart';
import 'package:qent/features/home/presentation/providers/car_providers.dart';
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

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    ref.read(searchControllerProvider.notifier).updateSearchQuery(
      _searchController.text,
    );
    setState(() {}); // Rebuild for clear button visibility
  }

  @override
  Widget build(BuildContext context) {
    final carsAsync = ref.watch(filteredCarsProvider);
    final filterOptionsState = ref.watch(filterOptionsControllerProvider);
    final searchState = ref.watch(searchControllerProvider);
    final authState = ref.watch(authControllerProvider);
    final userId = authState.user?.uid ?? '';
    final carController = ref.read(carControllerProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildSearchBar(context),
            ),
            const SizedBox(height: 16),
            _buildBrandFilters(context, filterOptionsState.options.brandFilters),
            const SizedBox(height: 24),
            Expanded(
              child: _buildResults(context, carsAsync, searchState, userId, carController),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 40),
          const Text(
            'Search',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.more_horiz, size: 20, color: Color(0xFF1A1A1A)),
            ),
          ),
        ],
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
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(Icons.search_rounded, color: Colors.grey[400], size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
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
                if (_searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () => _searchController.clear(),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(Icons.close_rounded, color: Colors.grey[400], size: 20),
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

  Widget _buildBrandFilters(BuildContext context, List<BrandFilter> brandFilters) {
    final searchState = ref.watch(searchControllerProvider);
    final selectedFilter = searchState.filters.selectedBrandFilter;

    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: brandFilters.length,
        itemBuilder: (context, index) {
          final filter = brandFilters[index];
          final isSelected = selectedFilter == filter.name;

          return Padding(
            padding: EdgeInsets.only(right: index < brandFilters.length - 1 ? 10 : 0),
            child: GestureDetector(
              onTap: () {
                ref.read(searchControllerProvider.notifier).updateBrandFilter(filter.name);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (filter.logoUrl != null) ...[
                      ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          isSelected ? Colors.white : const Color(0xFF1A1A1A),
                          BlendMode.srcIn,
                        ),
                        child: Image.network(
                          filter.logoUrl!,
                          width: 18,
                          height: 18,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.directions_car,
                            color: isSelected ? Colors.white : const Color(0xFF1A1A1A),
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (filter.name == 'ALL')
                      Icon(
                        Icons.apps_rounded,
                        color: isSelected ? Colors.white : Colors.grey[600],
                        size: 16,
                      ),
                    if (filter.name == 'ALL') const SizedBox(width: 6),
                    Text(
                      filter.name == 'Mercedes-Benz' ? 'Mercedes' : filter.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : Colors.grey[600],
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

  Widget _buildResults(BuildContext context, AsyncValue<List<Car>> carsAsync, dynamic searchState, String userId, CarController carController) {
    return carsAsync.when(
      data: (cars) {
        // Split into recommended (high rating) and all
        final recommended = cars.where((car) => car.rating >= 4.5).toList();

        if (cars.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text(
                  'No cars found',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Try adjusting your filters',
                  style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (recommended.isNotEmpty)
                _buildSection(
                  context,
                  title: 'Recommended',
                  subtitle: '${recommended.length} top rated',
                  cars: recommended,
                  userId: userId,
                  carController: carController,
                ),
              if (recommended.isNotEmpty) const SizedBox(height: 28),
              _buildSection(
                context,
                title: 'All Cars',
                subtitle: '${cars.length} available',
                cars: cars,
                userId: userId,
                carController: carController,
              ),
              const SizedBox(height: 100),
            ],
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A1A1A)),
      ),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('Failed to load cars', style: TextStyle(color: Colors.grey[400])),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => ref.invalidate(carsProvider),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('Retry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<Car> cars,
    required String userId,
    required CarController carController,
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
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
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
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'View All',
                  style: TextStyle(fontSize: 13, color: Colors.grey[400], fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: cars.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(right: index < cars.length - 1 ? 14 : 0),
                child: SearchCarCard(
                  car: cars[index],
                  onFavoriteTap: () {
                    if (userId.isNotEmpty) {
                      carController.toggleFavorite(cars[index].id);
                    }
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
