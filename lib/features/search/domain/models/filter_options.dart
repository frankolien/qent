/// Filter options that will be loaded from Firebase
class FilterOptions {
  final List<String> carTypes;
  final List<String> rentalTimes;
  final List<ColorOption> colors;
  final List<String> capacities;
  final List<String> fuelTypes;
  final List<BrandFilter> brandFilters;

  FilterOptions({
    required this.carTypes,
    required this.rentalTimes,
    required this.colors,
    required this.capacities,
    required this.fuelTypes,
    required this.brandFilters,
  });

  /// Default static options (will be replaced by Firebase data)
  factory FilterOptions.defaultOptions() {
    return FilterOptions(
      carTypes: ['All Cars', 'Regular Cars', 'Luxury Cars'],
      rentalTimes: ['Hour', 'Day', 'Weekly', 'Monthly'],
      colors: [
        ColorOption(name: 'White', colorValue: 0xFFFFFFFF),
        ColorOption(name: 'Gray', colorValue: 0xFF9E9E9E),
        ColorOption(name: 'Blue', colorValue: 0xFF2196F3),
        ColorOption(name: 'Black', colorValue: 0xFF000000),
      ],
      capacities: ['2', '4', '6', '8'],
      fuelTypes: ['Electric', 'Petrol', 'Diesel', 'Hybrid'],
      brandFilters: [
        BrandFilter(id: 'all', name: 'ALL', logoUrl: null),
        BrandFilter(id: 'ferrari', name: 'Ferrari', logoUrl: 'assets/images/Ferrari.png'),
        BrandFilter(id: 'tesla', name: 'Tesla', logoUrl: 'assets/images/Tesla.png'),
        BrandFilter(id: 'bmw', name: 'BMW', logoUrl: 'assets/images/Bmw.png'),
        BrandFilter(id: 'lamborghini', name: 'Lamborghini', logoUrl: 'assets/images/Lambo.png'),
      ],
    );
  }
}

class ColorOption {
  final String name;
  final int colorValue;

  ColorOption({
    required this.name,
    required this.colorValue,
  });
}

class BrandFilter {
  final String id;
  final String name;
  final String? logoUrl;

  BrandFilter({
    required this.id,
    required this.name,
    this.logoUrl,
  });
}

