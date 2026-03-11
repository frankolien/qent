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

// Tracks the set of favorited car IDs locally for instant UI updates
class FavoriteIdsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    _load();
    return <String>{};
  }

  Future<void> _load() async {
    try {
      final dataSource = ref.read(apiCarDataSourceProvider);
      final favCars = await dataSource.getFavoriteCars();
      state = favCars.map((c) => c.id).toSet();
    } catch (e) {
      debugPrint('[Qent Favorites] FAIL: Could not load favorites: $e');
    }
  }

  Future<void> toggle(String carId) async {
    final wasFavorited = state.contains(carId);
    // Optimistic update
    if (wasFavorited) {
      state = Set<String>.from(state)..remove(carId);
    } else {
      state = Set<String>.from(state)..add(carId);
    }

    try {
      final dataSource = ref.read(apiCarDataSourceProvider);
      final serverResult = await dataSource.toggleFavorite(carId);
      // Reconcile if server disagrees
      if (serverResult && !state.contains(carId)) {
        state = Set<String>.from(state)..add(carId);
      } else if (!serverResult && state.contains(carId)) {
        state = Set<String>.from(state)..remove(carId);
      }
    } catch (e) {
      debugPrint('[Qent Favorites] ERROR: toggle failed, reverting: $e');
      // Revert on error
      if (wasFavorited) {
        state = Set<String>.from(state)..add(carId);
      } else {
        state = Set<String>.from(state)..remove(carId);
      }
    }
  }
}

final favoriteIdsProvider =
    NotifierProvider<FavoriteIdsNotifier, Set<String>>(FavoriteIdsNotifier.new);

// Car controller for actions
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
