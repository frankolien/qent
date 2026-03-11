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
        BrandFilter(id: 'toyota', name: 'Toyota', logoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e7/Toyota.svg/200px-Toyota.svg.png'),
        BrandFilter(id: 'honda', name: 'Honda', logoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/76/Honda_logo.svg/200px-Honda_logo.svg.png'),
        BrandFilter(id: 'mercedes', name: 'Mercedes-Benz', logoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/90/Mercedes-Logo.svg/200px-Mercedes-Logo.svg.png'),
        BrandFilter(id: 'lexus', name: 'Lexus', logoUrl: 'https://upload.wikimedia.org/wikipedia/en/thumb/d/d1/Lexus_division_emblem.svg/200px-Lexus_division_emblem.svg.png'),
        BrandFilter(id: 'range_rover', name: 'Range Rover', logoUrl: 'https://www.carlogos.org/logo/Land-Rover-logo-2011-1920x1080.png'),
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

