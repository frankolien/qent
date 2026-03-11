import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/features/search/data/datasources/location_datasource.dart';
import 'package:qent/features/search/domain/models/location.dart';

final locationDataSourceProvider = Provider((ref) => LocationDataSource());

final userLocationProvider = AsyncNotifierProvider<UserLocationNotifier, LocationModel>(
  UserLocationNotifier.new,
);

class UserLocationNotifier extends AsyncNotifier<LocationModel> {
  @override
  Future<LocationModel> build() async {
    try {
      final ds = ref.read(locationDataSourceProvider);
      return await ds.getCurrentLocationWithAddress();
    } catch (_) {
      // Fallback to Lagos
      return LocationModel(
        id: 'default',
        name: 'Lagos',
        city: 'Lagos',
        state: 'Lagos State',
        country: 'Nigeria',
      );
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final ds = ref.read(locationDataSourceProvider);
      return await ds.getCurrentLocationWithAddress();
    });
  }

  void setLocation(LocationModel location) {
    state = AsyncData(location);
  }
}
