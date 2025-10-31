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
    );
  }
}

