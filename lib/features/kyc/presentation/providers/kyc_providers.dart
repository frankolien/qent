import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart';
import 'package:qent/features/kyc/data/datasources/kyc_datasource.dart';

final kycDataSourceProvider = Provider<KycDataSource>((ref) {
  final client = ref.watch(apiClientProvider);
  return KycDataSource(client: client);
});
