import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:qent/core/services/api_client.dart';
import 'package:qent/features/kyc/domain/models/kyc_access_token.dart';

class KycDataSource {
  final ApiClient _client;

  KycDataSource({ApiClient? client}) : _client = client ?? ApiClient();

  void _log(String m) {
    if (kDebugMode) debugPrint('[Qent KYC] $m');
  }

  /// Backend mints + returns. Requires the user's country to be set
  /// (the backend returns 412 otherwise).
  Future<KycAccessToken> fetchAccessToken() async {
    _log('> POST /kyc/access-token');
    final resp = await _client.post('/kyc/access-token');
    if (!resp.isSuccess) {
      throw KycException(resp.statusCode, resp.errorMessage);
    }
    return KycAccessToken.fromJson(resp.body as Map<String, dynamic>);
  }
}

class KycException implements Exception {
  final int statusCode;
  final String message;
  KycException(this.statusCode, this.message);

  bool get isCountryMissing => statusCode == 412;
  bool get isProviderNotConfigured => statusCode == 503;

  @override
  String toString() => message;
}
