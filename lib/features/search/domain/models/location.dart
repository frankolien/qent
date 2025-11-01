class LocationModel {
  final String id;
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? city;
  final String? state;
  final String? country;
  final bool isCurrentLocation;
  final DateTime? lastUsed;

  LocationModel({
    required this.id,
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
    this.city,
    this.state,
    this.country,
    this.isCurrentLocation = false,
    this.lastUsed,
  });

  String get displayName {
    if (address != null && address!.isNotEmpty) {
      return address!;
    }
    if (city != null && state != null) {
      return '$city, $state';
    }
    if (city != null) {
      return '$city, ${country ?? 'Nigeria'}';
    }
    return name;
  }

  LocationModel copyWith({
    String? id,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    String? city,
    String? state,
    String? country,
    bool? isCurrentLocation,
    DateTime? lastUsed,
  }) {
    return LocationModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      isCurrentLocation: isCurrentLocation ?? this.isCurrentLocation,
      lastUsed: lastUsed ?? this.lastUsed,
    );
  }

  /// Popular locations in Nigeria (default)
  static List<LocationModel> getPopularLocations() {
    return [
      LocationModel(
        id: 'lagos',
        name: 'Lagos',
        city: 'Lagos',
        state: 'Lagos State',
        country: 'Nigeria',
      ),
      LocationModel(
        id: 'abuja',
        name: 'Abuja',
        city: 'Abuja',
        state: 'FCT',
        country: 'Nigeria',
      ),
      LocationModel(
        id: 'port-harcourt',
        name: 'Port Harcourt',
        city: 'Port Harcourt',
        state: 'Rivers State',
        country: 'Nigeria',
      ),
      LocationModel(
        id: 'kano',
        name: 'Kano',
        city: 'Kano',
        state: 'Kano State',
        country: 'Nigeria',
      ),
      LocationModel(
        id: 'ibadan',
        name: 'Ibadan',
        city: 'Ibadan',
        state: 'Oyo State',
        country: 'Nigeria',
      ),
      LocationModel(
        id: 'benin',
        name: 'Benin City',
        city: 'Benin City',
        state: 'Edo State',
        country: 'Nigeria',
      ),
      LocationModel(
        id: 'ilorin',
        name: 'Ilorin',
        city: 'Ilorin',
        state: 'Kwara State',
        country: 'Nigeria',
      ),
      LocationModel(
        id: 'calabar',
        name: 'Calabar',
        city: 'Calabar',
        state: 'Cross River State',
        country: 'Nigeria',
      ),
    ];
  }
}

