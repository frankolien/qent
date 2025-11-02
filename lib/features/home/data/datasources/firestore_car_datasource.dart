import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qent/features/home/domain/models/car.dart';

class FirestoreCarDataSource {
  final FirebaseFirestore _firestore;

  FirestoreCarDataSource({required FirebaseFirestore firestore})
      : _firestore = firestore;

  // Stream of all cars
  Stream<List<Car>> getCarsStream() {
    return _firestore
        .collection('cars')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => _carFromFirestore(doc)).toList();
    });
  }

  // Stream of a single car
  Stream<Car?> getCarStream(String carId) {
    return _firestore
        .collection('cars')
        .doc(carId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return _carFromFirestore(doc);
    });
  }

  // Stream of favorite cars for current user
  Stream<List<Car>> getFavoriteCarsStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .snapshots()
        .asyncMap((snapshot) async {
      final favoriteIds = snapshot.docs.map((doc) => doc.id).toList();
      if (favoriteIds.isEmpty) return [];

      final cars = await Future.wait(
        favoriteIds.map((id) => _firestore.collection('cars').doc(id).get()),
      );

      return cars
          .where((doc) => doc.exists)
          .map((doc) => _carFromFirestore(doc))
          .toList();
    });
  }

  // Toggle favorite
  Future<void> toggleFavorite(String userId, String carId, bool isFavorite) async {
    final favoriteRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .doc(carId);

    if (isFavorite) {
      await favoriteRef.set({'carId': carId, 'addedAt': FieldValue.serverTimestamp()});
    } else {
      await favoriteRef.delete();
    }

    // Update car favorite count - use set with merge to avoid not-found errors
    try {
      final carRef = _firestore.collection('cars').doc(carId);
      final carDoc = await carRef.get();
      if (carDoc.exists) {
        await carRef.update({
          'isFavorite': isFavorite,
        });
      }
    } catch (e) {
      // Silently fail if car document doesn't exist
      // This can happen if the car was deleted but favorites reference it
    }
  }

  // Update car details
  Future<void> updateCar(String carId, Map<String, dynamic> updates) async {
    try {
      final carRef = _firestore.collection('cars').doc(carId);
      final carDoc = await carRef.get();
      if (carDoc.exists) {
        await carRef.update(updates);
      } else {
        throw Exception('Car document not found: $carId');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Helper method
  Car _carFromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Car(
      id: doc.id,
      name: data['name'] ?? '',
      brand: data['brand'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      location: data['location'] ?? '',
      seats: data['seats'] ?? 0,
      pricePerDay: (data['pricePerDay'] as num?)?.toDouble() ?? 0.0,
      isFavorite: data['isFavorite'] ?? false,
    );
  }
}

