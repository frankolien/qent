import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:qent/core/services/api_client.dart';
import 'package:qent/features/countries/domain/models/country.dart';

class CountriesDataSource {
  final ApiClient _client;

  CountriesDataSource({ApiClient? client}) : _client = client ?? ApiClient();

  void _log(String message) {
    if (kDebugMode) debugPrint('[Qent Countries] $message');
  }

  Future<List<Country>> listAll() async {
    _log('> GET /countries');
    final resp = await _client.get('/countries', auth: false);
    if (!resp.isSuccess) {
      throw Exception(resp.errorMessage);
    }
    final List<dynamic> data = resp.body;
    return data
        .whereType<Map<String, dynamic>>()
        .map(Country.fromJson)
        .toList();
  }

  Future<void> setMyCountry(String iso2) async {
    _log('> POST /users/me/country $iso2');
    final resp = await _client.post(
      '/users/me/country',
      body: {'iso2': iso2},
    );
    if (!resp.isSuccess) {
      throw Exception(resp.errorMessage);
    }
  }
}
