import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart';
import 'package:qent/features/discovery/data/datasources/discovery_datasource.dart';
import 'package:qent/features/discovery/domain/models/car_search_hit.dart';

final discoveryDataSourceProvider = Provider<DiscoveryDataSource>((ref) {
  final client = ref.watch(apiClientProvider);
  return DiscoveryDataSource(client: client);
});

class DiscoveryQuery {
  final String country;
  final String? city;
  final DateTime? startDate;
  final DateTime? endDate;
  final double? minPriceUsdc;
  final double? maxPriceUsdc;
  final String? sortBy;

  const DiscoveryQuery({
    required this.country,
    this.city,
    this.startDate,
    this.endDate,
    this.minPriceUsdc,
    this.maxPriceUsdc,
    this.sortBy,
  });

  @override
  bool operator ==(Object other) =>
      other is DiscoveryQuery &&
      country == other.country &&
      city == other.city &&
      startDate == other.startDate &&
      endDate == other.endDate &&
      minPriceUsdc == other.minPriceUsdc &&
      maxPriceUsdc == other.maxPriceUsdc &&
      sortBy == other.sortBy;

  @override
  int get hashCode => Object.hash(
        country,
        city,
        startDate,
        endDate,
        minPriceUsdc,
        maxPriceUsdc,
        sortBy,
      );
}

/// Fires GET /api/cars/search whenever the query changes. Pull-to-
/// refresh in the page calls `ref.invalidate(discoverySearchProvider(q))`.
final discoverySearchProvider = FutureProvider.autoDispose
    .family<List<CarSearchHit>, DiscoveryQuery>((ref, query) async {
  final ds = ref.watch(discoveryDataSourceProvider);
  return ds.search(
    country: query.country,
    city: query.city,
    startDate: query.startDate,
    endDate: query.endDate,
    minPriceUsdc: query.minPriceUsdc,
    maxPriceUsdc: query.maxPriceUsdc,
    sortBy: query.sortBy,
  );
});
