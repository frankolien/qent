/// V2 §4.1 step 6 — what POST /api/v2/bookings returns. Wraps the
/// booking summary plus the payment_intent sub-object the mobile
/// hands to the Privy SDK.
class PaymentIntentResponse {
  final String bookingId;
  final String paymentId;
  final String destination;
  final String amountUsdc;
  final String chain;
  final DateTime expiresAt;
  final int totalDays;
  final String hostPriceUsdc;
  final String serviceFeeUsdc;
  final String protectionPriceUsdc;
  final String totalUsdc;
  final String hostId;

  const PaymentIntentResponse({
    required this.bookingId,
    required this.paymentId,
    required this.destination,
    required this.amountUsdc,
    required this.chain,
    required this.expiresAt,
    required this.totalDays,
    required this.hostPriceUsdc,
    required this.serviceFeeUsdc,
    required this.protectionPriceUsdc,
    required this.totalUsdc,
    required this.hostId,
  });

  factory PaymentIntentResponse.fromJson(Map<String, dynamic> json) {
    // Backend returns a flat PaymentIntent struct from POST
    // /v2/bookings/:id/pay. Tolerate an older nested shape (in case
    // some response wraps under `payment_intent`) by merging.
    final nested = (json['payment_intent'] as Map?)?.cast<String, dynamic>();
    final src = <String, dynamic>{...json, if (nested != null) ...nested};
    final amount = (src['amount_usdc'] ?? '0').toString();
    return PaymentIntentResponse(
      bookingId: (src['booking_id'] ?? src['id'] ?? '').toString(),
      paymentId: (src['payment_id'] ?? '').toString(),
      destination: (src['destination'] ?? '').toString(),
      amountUsdc: amount,
      chain: (src['chain'] ?? 'base').toString(),
      expiresAt: DateTime.tryParse((src['expires_at'] ?? '').toString()) ??
          DateTime.now().add(const Duration(minutes: 15)),
      totalDays: (src['total_days'] as num?)?.toInt() ?? 0,
      hostPriceUsdc: (src['host_price_usdc'] ?? '0').toString(),
      serviceFeeUsdc: (src['service_fee_usdc'] ?? '0').toString(),
      protectionPriceUsdc:
          (src['protection_price_usdc'] ?? '0').toString(),
      totalUsdc: (src['total_usdc'] ?? amount).toString(),
      hostId: (src['host_id'] ?? '').toString(),
    );
  }
}
