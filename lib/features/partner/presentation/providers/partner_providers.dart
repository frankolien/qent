import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/features/partner/data/datasources/firestore_car_catalog_datasource.dart';

final carCatalogDataSourceProvider = Provider<FirestoreCarCatalogDataSource>((ref) {
  return FirestoreCarCatalogDataSource(firestore: FirebaseFirestore.instance);
});

final regularBrandsStreamProvider = StreamProvider<List<String>>((ref) {
  return ref.watch(carCatalogDataSourceProvider).streamBrands(category: 'regular');
});

final luxuryBrandsStreamProvider = StreamProvider<List<String>>((ref) {
  return ref.watch(carCatalogDataSourceProvider).streamBrands(category: 'luxury');
});

final modelsStreamProvider = StreamProvider.family<List<String>, String>((ref, brandName) {
  return ref.watch(carCatalogDataSourceProvider).streamModels(brandName: brandName);
});


