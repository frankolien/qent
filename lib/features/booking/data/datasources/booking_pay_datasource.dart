import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:qent/core/services/api_client.dart';
import 'package:qent/features/booking/domain/models/payment_intent.dart';

/// V2 USDC payment surface — bolts onto V1's booking lifecycle.
/// V1 still creates bookings via `POST /bookings`. This data source
/// only handles the *pay step* on an approved booking.
class BookingPayDataSource {
  final ApiClient _client;
  BookingPayDataSource({ApiClient? client}) : _client = client ?? ApiClient();

  void _log(String m) {
    if (kDebugMode) debugPrint('[Qent BookingV2] $m');
  }

  /// Renter taps Pay Now on an approved booking — backend computes
  /// USDC math, inserts a payment row, returns the payment intent
  /// (destination + amount). Idempotent on retry.
  Future<PaymentIntentResponse> requestPaymentIntent({
    required String bookingId,
  }) async {
    _log('> POST /bookings/$bookingId/pay-usdc');
    final resp = await _client.post('/bookings/$bookingId/pay-usdc');
    if (!resp.isSuccess) {
      throw BookingPayException(resp.statusCode, resp.errorMessage);
    }
    return PaymentIntentResponse.fromJson(resp.body as Map<String, dynamic>);
  }

  /// V2 §4.1 step 13 — bind tx_hash to the payment so the webhook
  /// (and reconciler fallback) can correlate the on-chain transfer.
  Future<void> submitTx({
    required String paymentId,
    required String txHash,
    required String fromAddress,
  }) async {
    _log('> POST /payments/$paymentId/submit-tx ${txHash.substring(0, 10)}…');
    final resp = await _client.post(
      '/payments/$paymentId/submit-tx',
      body: {'tx_hash': txHash, 'from_address': fromAddress},
    );
    if (!resp.isSuccess) {
      throw BookingPayException(resp.statusCode, resp.errorMessage);
    }
  }

  /// Polls `GET /bookings/{id}` until status is `paid` (or onward).
  /// Webhook fires near-instantly on success; reconciler picks up
  /// missed webhooks within 60s.
  Future<String> waitForPaid({
    required String bookingId,
    Duration timeout = const Duration(minutes: 2),
    Duration pollEvery = const Duration(seconds: 2),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final resp = await _client.get('/bookings/$bookingId');
      if (resp.isSuccess && resp.body is Map) {
        final status = (resp.body['status'] ?? '').toString();
        if (status == 'paid' ||
            status == 'active' ||
            status == 'completed' ||
            status == 'confirmed') {
          return status;
        }
        if (status == 'cancelled' || status == 'refunded') {
          throw BookingPayException(409, 'Booking $status');
        }
      }
      await Future.delayed(pollEvery);
    }
    throw BookingPayException(
      408,
      'Payment confirmation timed out. Pull to refresh and check status.',
    );
  }
}

class BookingPayException implements Exception {
  final int statusCode;
  final String message;
  BookingPayException(this.statusCode, this.message);
  bool get isNotApproved => statusCode == 409;
  bool get isNotConfigured => statusCode == 503;
  @override
  String toString() => message;
}
