import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:qent/core/services/api_client.dart';
import 'package:qent/features/home/domain/models/car.dart';

/// REST API datasource replacing Firestore car operations.
class ApiCarDataSource {
  final ApiClient _client;

  ApiCarDataSource({ApiClient? client}) : _client = client ?? ApiClient();

  void _log(String message) {
    if (kDebugMode) debugPrint('[Qent Cars] $message');
  }

  /// Fetch all available cars.
  Future<List<Car>> getCars() async {
    _log('> Fetching all cars');
    final sw = Stopwatch()..start();

    final response = await _client.get('/cars/search', auth: false, queryParams: {'per_page': '100'});
    sw.stop();

    if (!response.isSuccess) {
      _log('FAIL: getCars failed (${sw.elapsedMilliseconds}ms): ${response.errorMessage}');
      throw Exception(response.errorMessage);
    }

    final List<dynamic> data = response.body;
    final cars = data.map((json) => _carFromJson(json)).toList();
    _log('OK: Loaded ${cars.length} cars (${sw.elapsedMilliseconds}ms)');
    return cars;
  }

  /// Search cars with filters.
  Future<List<Car>> searchCars({
    String? location,
    double? minPrice,
    double? maxPrice,
    String? make,
    String? model,
    String? startDate,
    String? endDate,
    String? color,
    int? seats,
  }) async {
    final params = <String, String>{};
    if (location != null && location.isNotEmpty) params['location'] = location;
    if (minPrice != null) params['min_price'] = minPrice.toString();
    if (maxPrice != null) params['max_price'] = maxPrice.toString();
    if (make != null && make.isNotEmpty) params['make'] = make;
    if (model != null && model.isNotEmpty) params['model'] = model;
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    if (color != null && color.isNotEmpty) params['color'] = color;
    if (seats != null) params['seats'] = seats.toString();

    _log('> Searching cars | filters: $params');
    final sw = Stopwatch()..start();

    final response = await _client.get('/cars/search', auth: false, queryParams: params);
    sw.stop();

    if (!response.isSuccess) {
      _log('FAIL: searchCars failed (${sw.elapsedMilliseconds}ms): ${response.errorMessage}');
      throw Exception(response.errorMessage);
    }

    final List<dynamic> data = response.body;
    final cars = data.map((json) => _carFromJson(json)).toList();
    _log('OK: Search returned ${cars.length} cars (${sw.elapsedMilliseconds}ms)');
    return cars;
  }

  /// Fetch a single car by ID.
  Future<Car?> getCar(String carId) async {
    _log('> Fetching car: $carId');
    final sw = Stopwatch()..start();

    final response = await _client.get('/cars/$carId', auth: false);
    sw.stop();

    if (!response.isSuccess) {
      _log('FAIL: getCar failed (${sw.elapsedMilliseconds}ms): ${response.errorMessage}');
      return null;
    }

    final car = _carFromJson(response.body);
    _log('OK: Loaded car: ${car.name} (${sw.elapsedMilliseconds}ms)');
    return car;
  }

  /// Get favorite cars for current user.
  Future<List<Car>> getFavoriteCars() async {
    _log('> Fetching favorites');
    final sw = Stopwatch()..start();

    final response = await _client.get('/favorites');
    sw.stop();

    if (!response.isSuccess) {
      _log('FAIL: getFavorites failed (${sw.elapsedMilliseconds}ms): ${response.errorMessage}');
      return [];
    }

    final List<dynamic> data = response.body;
    final cars = data.map((json) => _carFromJson(json, isFavorite: true)).toList();
    _log('OK: Loaded ${cars.length} favorites (${sw.elapsedMilliseconds}ms)');
    return cars;
  }

  /// Toggle favorite status for a car.
  Future<bool> toggleFavorite(String carId) async {
    _log('> Toggling favorite: $carId');
    final sw = Stopwatch()..start();

    final response = await _client.post('/favorites/$carId');
    sw.stop();

    if (!response.isSuccess) {
      _log('FAIL: toggleFavorite failed (${sw.elapsedMilliseconds}ms): ${response.errorMessage}');
      throw Exception(response.errorMessage);
    }

    final favorited = response.body['favorited'] ?? false;
    _log('OK: Favorite toggled: $carId -> ${favorited ? "added" : "removed"} (${sw.elapsedMilliseconds}ms)');
    return favorited;
  }

  /// Check if a car is favorited.
  Future<bool> isFavorited(String carId) async {
    _log('> Checking favorite: $carId');
    final sw = Stopwatch()..start();

    final response = await _client.get('/favorites/$carId/check');
    sw.stop();

    if (!response.isSuccess) {
      _log('WARN: isFavorited check failed (${sw.elapsedMilliseconds}ms)');
      return false;
    }

    final favorited = response.body['favorited'] ?? false;
    _log('OK: Favorite check: $carId -> $favorited (${sw.elapsedMilliseconds}ms)');
    return favorited;
  }

  /// Fetch homepage sections: recommended, best_cars, nearby, popular.
  Future<Map<String, List<Car>>> getHomepage({double? latitude, double? longitude}) async {
    _log('> Fetching homepage sections');
    final sw = Stopwatch()..start();

    final params = <String, String>{};
    if (latitude != null) params['latitude'] = latitude.toString();
    if (longitude != null) params['longitude'] = longitude.toString();

    final response = await _client.get('/cars/homepage', auth: false, queryParams: params);
    sw.stop();

    if (!response.isSuccess) {
      _log('FAIL: getHomepage failed (${sw.elapsedMilliseconds}ms): ${response.errorMessage}');
      throw Exception(response.errorMessage);
    }

    final Map<String, dynamic> body = response.body;
    final result = <String, List<Car>>{};
    for (final key in ['recommended', 'best_cars', 'nearby', 'popular']) {
      final list = body[key] as List<dynamic>? ?? [];
      result[key] = list.map((json) => _carFromJson(json as Map<String, dynamic>)).toList();
    }
    _log('OK: Homepage loaded (${sw.elapsedMilliseconds}ms) - '
        'recommended: ${result["recommended"]?.length}, '
        'best: ${result["best_cars"]?.length}, '
        'nearby: ${result["nearby"]?.length}, '
        'popular: ${result["popular"]?.length}');
    return result;
  }

  /// Get host's own car listings.
  Future<List<Car>> getHostCars() async {
    _log('> Fetching host car listings');
    final sw = Stopwatch()..start();

    final response = await _client.get('/cars/my-listings');
    sw.stop();

    if (!response.isSuccess) {
      _log('FAIL: getHostCars failed (${sw.elapsedMilliseconds}ms): ${response.errorMessage}');
      throw Exception(response.errorMessage);
    }

    final List<dynamic> data = response.body;
    final cars = data.map((json) => _carFromJson(json)).toList();
    _log('OK: Loaded ${cars.length} host listings (${sw.elapsedMilliseconds}ms)');
    return cars;
  }

  /// Create a new car listing.
  Future<Car> createCar({
    required String make,
    required String model,
    required int year,
    required String color,
    required String plateNumber,
    required String description,
    required double pricePerDay,
    required String location,
    required List<String> photos,
    List<String>? features,
    int? seats,
  }) async {
    _log('> Creating car listing: $make $model');
    final sw = Stopwatch()..start();

    final response = await _client.post('/cars', body: {
      'make': make,
      'model': model,
      'year': year,
      'color': color,
      'plate_number': plateNumber,
      'description': description,
      'price_per_day': pricePerDay,
      'location': location,
      'photos': photos,
      if (features != null) 'features': features,
      if (seats != null) 'seats': seats,
    });
    sw.stop();

    if (!response.isSuccess) {
      _log('FAIL: createCar failed (${sw.elapsedMilliseconds}ms): ${response.errorMessage}');
      throw Exception(response.errorMessage);
    }

    final car = _carFromJson(response.body);
    _log('OK: Created car: ${car.name} (${sw.elapsedMilliseconds}ms)');
    return car;
  }

  /// Convert API JSON to Car model.
  Car _carFromJson(Map<String, dynamic> json, {bool isFavorite = false}) {
    final photos = json['photos'] as List<dynamic>?;
    final imageUrl = (photos != null && photos.isNotEmpty) ? photos[0] as String : '';

    final photosList = photos?.map((p) => p as String).toList() ?? [];
    final featuresList = (json['features'] as List<dynamic>?)?.map((f) => f as String).toList() ?? [];

    return Car(
      id: json['id'] ?? '',
      name: '${json['make'] ?? ''} ${json['model'] ?? ''} ${json['year'] ?? ''}'.trim(),
      brand: json['make'] ?? '',
      imageUrl: imageUrl,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      location: json['location'] ?? '',
      seats: json['seats'] ?? 5,
      pricePerDay: (json['price_per_day'] as num?)?.toDouble() ?? 0.0,
      isFavorite: isFavorite,
      description: json['description'] ?? '',
      photos: photosList,
      features: featuresList,
      color: json['color'] ?? '',
      year: json['year'] ?? 0,
      hostId: json['host_id'] ?? '',
      hostName: json['host_name'] ?? '',
      tripCount: (json['trip_count'] as num?)?.toInt() ?? 0,
    );
  }
}
