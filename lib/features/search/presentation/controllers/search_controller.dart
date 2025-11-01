import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/features/search/domain/models/search_filters.dart';
import 'package:qent/features/search/presentation/controllers/search_state.dart';

class SearchController extends Notifier<SearchState> {
  @override
  SearchState build() {
    return SearchState(
      filters: SearchFilters(),
    );
  }

  void updateBrandFilter(String brand) {
    state = state.copyWith(
      filters: state.filters.copyWith(selectedBrandFilter: brand),
    );
  }

  void updateSearchQuery(String query) {
    state = state.copyWith(
      filters: state.filters.copyWith(searchQuery: query),
    );
  }

  void updateCarType(String? carType) {
    state = state.copyWith(
      filters: state.filters.copyWith(selectedCarType: carType),
    );
  }

  void updatePriceRange(RangeValues priceRange) {
    state = state.copyWith(
      filters: state.filters.copyWith(priceRange: priceRange),
    );
  }

  void updateRentalTime(String? rentalTime) {
    state = state.copyWith(
      filters: state.filters.copyWith(selectedRentalTime: rentalTime),
    );
  }

  void updateDateRange({
    DateTime? startDate,
    DateTime? endDate,
    TimeOfDay? pickupTime,
    TimeOfDay? dropTime,
  }) {
    state = state.copyWith(
      filters: state.filters.copyWith(
        startDate: startDate,
        endDate: endDate,
        pickupTime: pickupTime,
        dropTime: dropTime,
      ),
    );
  }

  void updateLocation(String? location) {
    state = state.copyWith(
      filters: state.filters.copyWith(location: location),
    );
  }

  void updateColor(String? color) {
    state = state.copyWith(
      filters: state.filters.copyWith(selectedColor: color),
    );
  }

  void updateCapacity(String? capacity) {
    state = state.copyWith(
      filters: state.filters.copyWith(selectedCapacity: capacity),
    );
  }

  void updateFuelType(String? fuelType) {
    state = state.copyWith(
      filters: state.filters.copyWith(selectedFuelType: fuelType),
    );
  }

  void clearAllFilters() {
    state = SearchState(
      filters: SearchFilters(),
    );
  }
}

