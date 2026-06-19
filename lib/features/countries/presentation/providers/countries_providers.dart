import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart';
import 'package:qent/features/countries/data/datasources/countries_datasource.dart';
import 'package:qent/features/countries/domain/models/country.dart';

final countriesDataSourceProvider = Provider<CountriesDataSource>((ref) {
  final client = ref.watch(apiClientProvider);
  return CountriesDataSource(client: client);
});

/// All countries — cached for the session, refreshable via `ref.invalidate`.
final countriesListProvider = FutureProvider<List<Country>>((ref) async {
  final ds = ref.watch(countriesDataSourceProvider);
  final list = await ds.listAll();
  // Supported markets first, then alphabetical.
  list.sort((a, b) {
    if (a.supported != b.supported) return a.supported ? -1 : 1;
    return a.name.compareTo(b.name);
  });
  return list;
});
