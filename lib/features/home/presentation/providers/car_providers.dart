import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart';
import 'package:qent/features/home/data/datasources/firestore_car_datasource.dart';
import 'package:qent/features/home/domain/models/car.dart';

// Reuse existing providers from auth_providers

final firestoreCarDataSourceProvider = Provider<FirestoreCarDataSource>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return FirestoreCarDataSource(firestore: firestore);
});

// Stream provider for all cars
final carsStreamProvider = StreamProvider<List<Car>>((ref) {
  final dataSource = ref.watch(firestoreCarDataSourceProvider);
  return dataSource.getCarsStream();
});

// Stream provider for a single car
final carStreamProvider = StreamProvider.family<Car?, String>((ref, carId) {
  final dataSource = ref.watch(firestoreCarDataSourceProvider);
  return dataSource.getCarStream(carId);
});

// Stream provider for favorite cars
final favoriteCarsStreamProvider = StreamProvider<List<Car>>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final userId = auth.currentUser?.uid;
  if (userId == null) {
    return Stream.value([]);
  }
  final dataSource = ref.watch(firestoreCarDataSourceProvider);
  return dataSource.getFavoriteCarsStream(userId);
});

// Car controller
class CarController {
  final FirestoreCarDataSource _dataSource;

  CarController(this._dataSource);

  Future<void> toggleFavorite(String userId, String carId, bool isFavorite) async {
    try {
      await _dataSource.toggleFavorite(userId, carId, isFavorite);
    } catch (e) {
      rethrow;
    }
  }
}

final carControllerProvider = Provider<CarController>((ref) {
  final dataSource = ref.watch(firestoreCarDataSourceProvider);
  return CarController(dataSource);
});

