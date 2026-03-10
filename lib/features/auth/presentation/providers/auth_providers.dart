import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/core/services/api_client.dart';
import 'package:qent/features/auth/data/datasources/api_auth_datasource.dart';
import 'package:qent/features/home/data/datasources/api_car_datasource.dart';
import 'package:qent/features/auth/presentation/controllers/auth_controller.dart';
import 'package:qent/features/auth/presentation/controllers/auth_state.dart';

// API client singleton
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

// Auth data source
final apiAuthDataSourceProvider = Provider<ApiAuthDataSource>((ref) {
  final client = ref.watch(apiClientProvider);
  return ApiAuthDataSource(client: client);
});

// Car data source (shared across the app)
final apiCarDataSourceProvider = Provider<ApiCarDataSource>((ref) {
  final client = ref.watch(apiClientProvider);
  return ApiCarDataSource(client: client);
});

// Auth controller
final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);
