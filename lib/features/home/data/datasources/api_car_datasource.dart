import 'dart:async';
import 'package:qent/core/services/api_client.dart';
import 'package:qent/features/home/domain/models/car.dart';

/// REST API datasource replacing Firestore car operations.
class ApiCarDataSource {
  final ApiClient _client;

  ApiCarDataSource({ApiClient? client}) : _client = client ?? ApiClient();

  /// Fetch all available cars.
  Future<List<Car>> getCars() async {
    final response = await _client.get('/cars/search', auth: false);

    if (!response.isSuccess) {
      throw Exception(response.errorMessage);
    }

    final List<dynamic> data = response.body;
    return data.map((json) => _carFromJson(json)).toList();
  }

  /// Search cars with filters.
  Future<List<Car>> searchCars({
    String? location,
    double? minPrice,
    double? maxPrice,
    String? make,
    String? model,
  }) async {
    final params = <String, String>{};
    if (location != null) params['location'] = location;
    if (minPrice != null) params['min_price'] = minPrice.toString();
    if (maxPrice != null) params['max_price'] = maxPrice.toString();
    if (make != null) params['make'] = make;
    if (model != null) params['model'] = model;

    final response = await _client.get('/cars/search', auth: false, queryParams: params);

    if (!response.isSuccess) {
      throw Exception(response.errorMessage);
    }

    final List<dynamic> data = response.body;
    return data.map((json) => _carFromJson(json)).toList();
  }

  /// Fetch a single car by ID.
  Future<Car?> getCar(String carId) async {
    final response = await _client.get('/cars/$carId', auth: false);

    if (!response.isSuccess) return null;

    return _carFromJson(response.body);
  }

  /// Get favorite cars for current user.
  Future<List<Car>> getFavoriteCars() async {
    final response = await _client.get('/favorites');

    if (!response.isSuccess) {
      return [];
    }

    final List<dynamic> data = response.body;
    return data.map((json) => _carFromJson(json, isFavorite: true)).toList();
  }

  /// Toggle favorite status for a car.
  Future<bool> toggleFavorite(String carId) async {
    final response = await _client.post('/favorites/$carId');

    if (!response.isSuccess) {
      throw Exception(response.errorMessage);
    }

    return response.body['favorited'] ?? false;
  }

  /// Check if a car is favorited.
  Future<bool> isFavorited(String carId) async {
    final response = await _client.get('/favorites/$carId/check');

    if (!response.isSuccess) return false;

    return response.body['favorited'] ?? false;
  }

  /// Get host's own car listings.
  Future<List<Car>> getHostCars() async {
    final response = await _client.get('/cars/my-listings');

    if (!response.isSuccess) {
      throw Exception(response.errorMessage);
    }

    final List<dynamic> data = response.body;
    return data.map((json) => _carFromJson(json)).toList();
  }

  /// Convert API JSON to Car model.
  /// Maps Rust backend fields to Flutter Car model fields.
  Car _carFromJson(Map<String, dynamic> json, {bool isFavorite = false}) {
    final photos = json['photos'] as List<dynamic>?;
    final imageUrl = (photos != null && photos.isNotEmpty) ? photos[0] as String : '';

    return Car(
      id: json['id'] ?? '',
      name: '${json['make'] ?? ''} ${json['model'] ?? ''} ${json['year'] ?? ''}'.trim(),
      brand: json['make'] ?? '',
      imageUrl: imageUrl,
      rating: 0.0, // Rating is fetched separately from reviews
      location: json['location'] ?? '',
      seats: json['seats'] ?? 5,
      pricePerDay: (json['price_per_day'] as num?)?.toDouble() ?? 0.0,
      isFavorite: isFavorite,
    );
  }
}
