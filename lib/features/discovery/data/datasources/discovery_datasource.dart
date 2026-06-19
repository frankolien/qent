import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:qent/core/services/api_client.dart';
import 'package:qent/features/discovery/domain/models/car_search_hit.dart';

class DiscoveryDataSource {
  final ApiClient _client;

  DiscoveryDataSource({ApiClient? client}) : _client = client ?? ApiClient();

  void _log(String m) {
    if (kDebugMode) debugPrint('[Qent Discovery] $m');
  }

  Future<List<CarSearchHit>> search({
    required String country,
    String? city,
    DateTime? startDate,
    DateTime? endDate,
    double? minPriceUsdc,
    double? maxPriceUsdc,
    String? sortBy,
    int page = 1,
    int perPage = 20,
  }) async {
    final params = <String, String>{
      'country': country.toUpperCase(),
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (city != null && city.isNotEmpty) params['city'] = city;
    if (startDate != null) {
      params['start_date'] = _dateOnly(startDate);
    }
    if (endDate != null) {
      params['end_date'] = _dateOnly(endDate);
    }
    if (minPriceUsdc != null) params['min_price_usdc'] = minPriceUsdc.toString();
    if (maxPriceUsdc != null) params['max_price_usdc'] = maxPriceUsdc.toString();
    if (sortBy != null && sortBy.isNotEmpty) params['sort_by'] = sortBy;

    _log('> GET /v2/cars/search $params');
    final resp = await _client.get(
      '/v2/cars/search',
      auth: false,
      queryParams: params,
    );
    if (!resp.isSuccess) {
      throw Exception(resp.errorMessage);
    }
    final List<dynamic> data = resp.body;
    return data
        .whereType<Map<String, dynamic>>()
        .map(CarSearchHit.fromJson)
        .toList();
  }

  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
