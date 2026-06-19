/// V2 §7 — single result row returned by GET /api/v2/cars/search.
///
/// Slimmer than the V1 `Car` model — only the fields the discovery
/// card needs. Detail view still hits /api/cars/{id} for the full
/// payload.
class CarSearchHit {
  final String id;
  final String make;
  final String model;
  final int year;
  final List<String> photos;
  final String? country;
  final String city;
  final String location;
  /// USDC. Backend serializes `rust_decimal::Decimal` as a string in
  /// JSON; we parse to double for display, which is safe for any
  /// realistic rental price.
  final double pricePerDayUsdc;
  final bool instantBook;
  final int minTripDays;
  final double? rating;
  final int? tripCount;
  final String? hostName;
  final DateTime createdAt;

  const CarSearchHit({
    required this.id,
    required this.make,
    required this.model,
    required this.year,
    required this.photos,
    this.country,
    required this.city,
    required this.location,
    required this.pricePerDayUsdc,
    required this.instantBook,
    required this.minTripDays,
    this.rating,
    this.tripCount,
    this.hostName,
    required this.createdAt,
  });

  factory CarSearchHit.fromJson(Map<String, dynamic> json) {
    double parsePrice(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    return CarSearchHit(
      id: json['id'] as String,
      make: json['make'] as String? ?? '',
      model: json['model'] as String? ?? '',
      year: (json['year'] as num?)?.toInt() ?? 0,
      photos: (json['photos'] as List?)?.cast<String>() ?? const [],
      country: json['country'] as String?,
      city: json['city'] as String? ?? '',
      location: json['location'] as String? ?? '',
      pricePerDayUsdc: parsePrice(json['price_per_day_usdc']),
      instantBook: json['instant_book'] as bool? ?? false,
      minTripDays: (json['min_trip_days'] as num?)?.toInt() ?? 1,
      rating: (json['rating'] as num?)?.toDouble(),
      tripCount: (json['trip_count'] as num?)?.toInt(),
      hostName: json['host_name'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
