import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart';
import 'package:qent/features/home/domain/models/car.dart';
import 'package:qent/features/home/presentation/providers/location_provider.dart';
import 'package:qent/features/search/presentation/controllers/search_controller.dart';
import 'package:qent/features/search/presentation/controllers/search_state.dart';
import 'package:qent/features/search/presentation/controllers/filter_options_controller.dart';
import 'package:qent/features/search/presentation/controllers/filter_options_state.dart';

/// Provider for search controller
final searchControllerProvider = NotifierProvider<SearchController, SearchState>(
  () => SearchController(),
);

/// Provider for filter options controller
final filterOptionsControllerProvider = NotifierProvider<FilterOptionsController, FilterOptionsState>(
  () => FilterOptionsController(),
);

/// Reactive provider that fetches cars from API whenever filters change
final filteredCarsProvider = FutureProvider<List<Car>>((ref) async {
  final searchState = ref.watch(searchControllerProvider);
  final filters = searchState.filters;
  final dataSource = ref.watch(apiCarDataSourceProvider);

  // Map brand filter to make param (skip if "ALL")
  String? make;
  if (filters.selectedBrandFilter != 'ALL') {
    make = filters.selectedBrandFilter;
    // Handle display names vs API names
    if (make == 'Mercedes-Benz') make = 'Mercedes';
  }

  // Map price range (only send if not at defaults)
  double? minPrice;
  double? maxPrice;
  if (filters.priceRange.start > 10000) minPrice = filters.priceRange.start;
  if (filters.priceRange.end < 200000) maxPrice = filters.priceRange.end;

  // Map dates
  String? startDate;
  String? endDate;
  if (filters.startDate != null) {
    startDate = '${filters.startDate!.year}-${filters.startDate!.month.toString().padLeft(2, '0')}-${filters.startDate!.day.toString().padLeft(2, '0')}';
  }
  if (filters.endDate != null) {
    endDate = '${filters.endDate!.year}-${filters.endDate!.month.toString().padLeft(2, '0')}-${filters.endDate!.day.toString().padLeft(2, '0')}';
  }

  // Map capacity to int
  int? seats;
  if (filters.selectedCapacity != null) {
    seats = int.tryParse(filters.selectedCapacity!);
  }

  // Get user location for distance sorting
  double? latitude;
  double? longitude;
  try {
    final loc = ref.read(userLocationProvider).value;
    latitude = loc?.latitude;
    longitude = loc?.longitude;
  } catch (_) {}

  final cars = await dataSource.searchCars(
    location: filters.location,
    minPrice: minPrice,
    maxPrice: maxPrice,
    make: make,
    startDate: startDate,
    endDate: endDate,
    color: filters.selectedColor,
    seats: seats,
    latitude: latitude,
    longitude: longitude,
  );

  // Client-side filters for things the API doesn't support
  var filtered = cars.toList();

  // Search query (client-side text search)
  final query = filters.searchQuery.toLowerCase();
  if (query.isNotEmpty) {
    filtered = filtered.where((car) =>
      car.name.toLowerCase().contains(query) ||
      car.brand.toLowerCase().contains(query) ||
      car.location.toLowerCase().contains(query)).toList();
  }

  // Fuel type (not in DB, filter client-side by features)
  if (filters.selectedFuelType != null) {
    filtered = filtered.where((car) =>
      car.features.any((f) => f.toLowerCase().contains(filters.selectedFuelType!.toLowerCase()))).toList();
  }

  // Car type filter (luxury vs regular)
  if (filters.selectedCarType != null && filters.selectedCarType != 'All Cars') {
    if (filters.selectedCarType == 'Luxury Cars') {
      const luxuryBrands = ['mercedes', 'bmw', 'audi', 'lexus', 'range rover', 'porsche', 'ferrari', 'lamborghini', 'bentley', 'rolls-royce', 'maserati'];
      filtered = filtered.where((car) =>
        luxuryBrands.any((b) => car.brand.toLowerCase().contains(b))).toList();
    } else if (filters.selectedCarType == 'Regular Cars') {
      const luxuryBrands = ['mercedes', 'bmw', 'audi', 'lexus', 'range rover', 'porsche', 'ferrari', 'lamborghini', 'bentley', 'rolls-royce', 'maserati'];
      filtered = filtered.where((car) =>
        !luxuryBrands.any((b) => car.brand.toLowerCase().contains(b))).toList();
    }
  }

  return filtered;
});
