import 'package:flutter/material.dart';

class SearchFilters {
  final String selectedBrandFilter;
  final String searchQuery;
  final String? selectedCarType;
  final RangeValues priceRange;
  final String? selectedRentalTime;
  final DateTime? startDate;
  final DateTime? endDate;
  final TimeOfDay? pickupTime;
  final TimeOfDay? dropTime;
  final String? location;
  final String? selectedColor;
  final String? selectedCapacity;
  final String? selectedFuelType;

  SearchFilters({
    this.selectedBrandFilter = 'ALL',
    this.searchQuery = '',
    this.selectedCarType,
    RangeValues? priceRange,
    this.selectedRentalTime,
    this.startDate,
    this.endDate,
    this.pickupTime,
    this.dropTime,
    this.location,
    this.selectedColor,
    this.selectedCapacity,
    this.selectedFuelType,
  }) : priceRange = priceRange ?? const RangeValues(10, 230);

  SearchFilters copyWith({
    String? selectedBrandFilter,
    String? searchQuery,
    String? selectedCarType,
    RangeValues? priceRange,
    String? selectedRentalTime,
    DateTime? startDate,
    DateTime? endDate,
    TimeOfDay? pickupTime,
    TimeOfDay? dropTime,
    String? location,
    String? selectedColor,
    String? selectedCapacity,
    String? selectedFuelType,
  }) {
    return SearchFilters(
      selectedBrandFilter: selectedBrandFilter ?? this.selectedBrandFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCarType: selectedCarType ?? this.selectedCarType,
      priceRange: priceRange ?? this.priceRange,
      selectedRentalTime: selectedRentalTime ?? this.selectedRentalTime,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      pickupTime: pickupTime ?? this.pickupTime,
      dropTime: dropTime ?? this.dropTime,
      location: location ?? this.location,
      selectedColor: selectedColor ?? this.selectedColor,
      selectedCapacity: selectedCapacity ?? this.selectedCapacity,
      selectedFuelType: selectedFuelType ?? this.selectedFuelType,
    );
  }

  SearchFilters clearAll() {
    return SearchFilters();
  }
}

