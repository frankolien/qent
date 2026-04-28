import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/core/services/api_client.dart';
import 'package:qent/features/car_details/domain/models/car_detail.dart';

/// Fetches all reviews for a given car id from GET /cars/{id}/reviews.
final carReviewsProvider =
    FutureProvider.family<List<Review>, String>((ref, carId) async {
  final res = await ApiClient().get('/cars/$carId/reviews', auth: false);
  if (!res.isSuccess) {
    throw Exception(res.errorMessage);
  }
  final body = res.body;
  if (body is! List) return const <Review>[];
  return body
      .whereType<Map<String, dynamic>>()
      .map(Review.fromBackendJson)
      .toList();
});
