import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/core/theme/app_theme.dart';
import 'package:qent/features/booking/data/datasources/booking_pay_datasource.dart';
import 'package:qent/features/booking/domain/models/payment_intent.dart';
import 'package:qent/features/booking/presentation/pages/booking_success_page.dart';
import 'package:qent/features/home/domain/models/car.dart';

/// V2 §4.1 step 14 — full-screen "waiting for chain confirmation"
/// state. Polls /bookings/:id; flips to BookingSuccessPage when the
/// Alchemy webhook (or reconciler fallback) marks it `paid`.
class BookingWaitingPage extends ConsumerStatefulWidget {
  final Car car;
  final PaymentIntentResponse intent;

  const BookingWaitingPage({
    super.key,
    required this.car,
    required this.intent,
  });

  @override
  ConsumerState<BookingWaitingPage> createState() =>
      _BookingWaitingPageState();
}

class _BookingWaitingPageState extends ConsumerState<BookingWaitingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  String? _error;
  int _elapsedSecs = 0;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSecs++);
    });
    _waitForConfirmation();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _waitForConfirmation() async {
    try {
      await BookingPayDataSource().waitForPaid(
        bookingId: widget.intent.bookingId,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BookingSuccessPage(
            car: widget.car,
            intent: widget.intent,
          ),
        ),
      );
    } on BookingPayException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Couldn\'t verify payment. Check Bookings.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgPrimary,
      // No back button — payment is mid-flight; abandoning here would
      // create a phantom payment on chain without a paid booking.
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),
              FadeTransition(
                opacity: Tween<double>(begin: 0.4, end: 1.0).animate(_pulse),
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: (context.isDark
                            ? const Color(0xFF22C55E)
                            : const Color(0xFF1A1A1A))
                        .withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: context.isDark
                            ? const Color(0xFF22C55E)
                            : const Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                _error == null
                    ? 'Confirming on Base...'
                    : 'Confirmation slow',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  _error ??
                      'Your USDC transfer is on chain. Most bookings confirm '
                          'in 1-3 seconds.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_error == null)
                _statBlock(context, 'Elapsed', '${_elapsedSecs}s'),
              const Spacer(),
              if (_error != null)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.textPrimary,
                      side: BorderSide(color: context.borderColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Back to home',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Keep this screen open',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textTertiary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statBlock(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: context.inputBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: context.textTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: context.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
