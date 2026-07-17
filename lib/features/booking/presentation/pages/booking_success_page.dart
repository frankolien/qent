import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/core/theme/app_theme.dart';
import 'package:qent/features/booking/domain/models/payment_intent.dart';
import 'package:qent/features/home/domain/models/car.dart';

/// V2 §4.1 step 17 — full-screen "Booking confirmed" surface.
/// Replaces the V1 success dialog. End of the renter flow.
class BookingSuccessPage extends ConsumerWidget {
  final Car car;
  final PaymentIntentResponse intent;

  const BookingSuccessPage({
    super.key,
    required this.car,
    required this.intent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.bgPrimary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  color: Color(0xFF22C55E),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 52,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Booking confirmed',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your USDC payment was received. The host is on the way '
                'to handing off the keys.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: context.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              _tripCard(context),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.isDark
                        ? const Color(0xFF22C55E)
                        : const Color(0xFF1A1A1A),
                    foregroundColor:
                        context.isDark ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Back to home',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tripCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.inputBg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 72,
              height: 56,
              child: car.photos.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: car.photos.first,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: context.bgPrimary),
                      errorWidget: (_, __, ___) => Container(
                        color: context.bgPrimary,
                        child: const Icon(
                          Icons.directions_car_rounded,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : Container(
                      color: context.bgPrimary,
                      child: const Icon(
                        Icons.directions_car_rounded,
                        color: Colors.grey,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  car.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Paid \$${_fmtUsdc(intent.totalUsdc)} USDC · ${intent.totalDays} day${intent.totalDays == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Trim ".000000" tails from rust_decimal's wire format ("365.848000"
  // → "365.85"). Two-decimal cents is the standard money display.
  String _fmtUsdc(String raw) {
    final v = double.tryParse(raw) ?? 0;
    return v.toStringAsFixed(2);
  }
}
