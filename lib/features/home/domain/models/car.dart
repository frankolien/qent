class Car {
  final String id;
  final String name;
  final String brand;
  final String imageUrl;
  final double rating;
  final String location;
  final int seats;
  final double pricePerDay;
  final bool isFavorite;
  final String description;
  final List<String> photos;
  final List<String> features;
  final String color;
  final int year;
  final String hostId;
  final String hostName;
  final int tripCount;

  Car({
    required this.id,
    required this.name,
    required this.brand,
    required this.imageUrl,
    required this.rating,
    required this.location,
    required this.seats,
    required this.pricePerDay,
    this.isFavorite = false,
    this.description = '',
    this.photos = const [],
    this.features = const [],
    this.color = '',
    this.year = 0,
    this.hostId = '',
    this.hostName = '',
    this.tripCount = 0,
  });

  Car copyWith({
    String? id,
    String? name,
    String? brand,
    String? imageUrl,
    double? rating,
    String? location,
    int? seats,
    double? pricePerDay,
    bool? isFavorite,
    String? description,
    List<String>? photos,
    List<String>? features,
    String? color,
    int? year,
    String? hostId,
    String? hostName,
    int? tripCount,
  }) {
    return Car(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      imageUrl: imageUrl ?? this.imageUrl,
      rating: rating ?? this.rating,
      location: location ?? this.location,
      seats: seats ?? this.seats,
      pricePerDay: pricePerDay ?? this.pricePerDay,
      isFavorite: isFavorite ?? this.isFavorite,
      description: description ?? this.description,
      photos: photos ?? this.photos,
      features: features ?? this.features,
      color: color ?? this.color,
      year: year ?? this.year,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      tripCount: tripCount ?? this.tripCount,
    );
  }
}

