import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreCarCatalogDataSource {
  final FirebaseFirestore _firestore;
  FirestoreCarCatalogDataSource({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  static const List<String> _defaultRegularBrands = [
    'Toyota', 'Honda', 'Nissan', 'Ford', 'Chevrolet', 'Hyundai', 'Kia', 'Volkswagen', 'Mazda', 'Subaru', 'Renault', 'Peugeot', 'Skoda', 'Fiat', 'Citroen', 'Volvo'
  ];

  static const List<String> _defaultLuxuryBrands = [
    'BMW', 'Mercedes-Benz', 'Audi', 'Lexus', 'Jaguar', 'Porsche', 'Bentley', 'Rolls-Royce', 'Ferrari', 'Lamborghini', 'Maserati', 'Aston Martin', 'Maybach'
  ];

  static const Map<String, List<String>> _defaultModels = {
    'Toyota': ['Corolla', 'Camry', 'RAV4', 'Yaris'],
    'Honda': ['Civic', 'Accord', 'CR-V'],
    'Nissan': ['Altima', 'Sentra', 'Rogue'],
    'BMW': ['3 Series', '5 Series', 'X5', 'X3'],
    'Mercedes-Benz': ['C-Class', 'E-Class', 'GLC'],
    'Audi': ['A4', 'A6', 'Q5'],
    'Lexus': ['ES', 'RX', 'NX'],
    'Porsche': ['Cayenne', 'Macan', '911'],
    'Bentley': ['Bentayga', 'Flying Spur', 'Continental GT'],
    'Ferrari': ['488', 'F8 Tributo', 'Roma'],
    'Lamborghini': ['Huracan', 'Urus', 'Aventador'],
  };

  // Streams a list of brand names filtered by category: 'regular' or 'luxury'
  Stream<List<String>> streamBrands({required String category}) {
    return _firestore
        .collection('car_brands')
        .where('category', isEqualTo: category)
        .snapshots()
        .map((s) {
          final list = s.docs
              .map((d) => (d.data()['name'] as String?) ?? '')
              .where((e) => e.isNotEmpty)
              .toList();
          if (list.isNotEmpty) {
            list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
            return list;
          }
          // Fallback to defaults when not yet seeded in Firestore
          return category == 'luxury' ? List<String>.from(_defaultLuxuryBrands) : List<String>.from(_defaultRegularBrands);
        });
  }

  // Streams models for a brand document: we support either subcollection `models` (each doc has name)
  // or the field `models` as an array of strings; the code handles both.
  Stream<List<String>> streamModels({required String brandName}) {
    final query = _firestore.collection('car_brands').where('name', isEqualTo: brandName).limit(1);
    return query.snapshots().asyncMap((snapshot) async {
      if (snapshot.docs.isEmpty) return <String>[];
      final doc = snapshot.docs.first;
      final data = doc.data();
      final fieldModels = (data['models'] as List?)?.whereType<String>().toList();
      if (fieldModels != null && fieldModels.isNotEmpty) return fieldModels..sort();

      final modelsSnap = await doc.reference.collection('models').orderBy('name').get();
      final fromSub = modelsSnap.docs.map((d) => (d.data()['name'] as String?) ?? '').where((e) => e.isNotEmpty).toList();
      if (fromSub.isNotEmpty) return fromSub;
      // Fallback defaults if nothing seeded
      return List<String>.from(_defaultModels[brandName] ?? const <String>[]);
    });
  }
}


