import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart';
import 'package:qent/features/home/data/datasources/api_car_datasource.dart';
import 'package:qent/features/home/domain/models/car.dart';

// Future provider for all cars (replaces Firestore StreamProvider)
final carsProvider = FutureProvider<List<Car>>((ref) async {
  final dataSource = ref.watch(apiCarDataSourceProvider);
  return dataSource.getCars();
});

// Future provider for a single car
final carProvider = FutureProvider.family<Car?, String>((ref, carId) async {
  final dataSource = ref.watch(apiCarDataSourceProvider);
  return dataSource.getCar(carId);
});

// Future provider for favorite cars
final favoriteCarsProvider = FutureProvider<List<Car>>((ref) async {
  final dataSource = ref.watch(apiCarDataSourceProvider);
  return dataSource.getFavoriteCars();
});

// Car controller for actions (toggleFavorite no longer needs userId - backend knows from JWT)
class CarController {
  final ApiCarDataSource _dataSource;

  CarController(this._dataSource);

  Future<bool> toggleFavorite(String carId) async {
    try {
      return await _dataSource.toggleFavorite(carId);
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      return false;
    }
  }
}

final carControllerProvider = Provider<CarController>((ref) {
  final dataSource = ref.watch(apiCarDataSourceProvider);
  return CarController(dataSource);
});
