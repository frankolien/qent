import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/core/theme/app_theme.dart';
import 'package:qent/features/booking/data/datasources/booking_pay_datasource.dart';
import 'package:qent/features/booking/data/services/usdc_transfer_service.dart';
import 'package:qent/features/booking/domain/models/payment_intent.dart';
import 'package:qent/features/booking/presentation/pages/booking_waiting_page.dart';
import 'package:qent/features/home/domain/models/car.dart';

/// V2 §4.1 step 11 — full-screen confirm of the USDC charge before
/// the Privy biometric prompt. Replaces the V1 dialog popup so the
/// payment flow gets its own dedicated surface.
class BookingConfirmPage extends ConsumerStatefulWidget {
  final Car car;
  final PaymentIntentResponse intent;
  final DateTime pickupDate;
  final DateTime returnDate;

  const BookingConfirmPage({
    super.key,
    required this.car,
    required this.intent,
    required this.pickupDate,
    required this.returnDate,
  });

  @override
  ConsumerState<BookingConfirmPage> createState() => _BookingConfirmPageState();
}

class _BookingConfirmPageState extends ConsumerState<BookingConfirmPage> {
  bool _busy = false;
  String? _error;

  final _bookings = BookingPayDataSource();
  final _usdc = UsdcTransferService();

  Future<void> _payWithWallet() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Privy biometric is surfaced natively by the SDK.
      final transfer = await _usdc.sendToEscrow(
        destination: widget.intent.destination,
        amountUsdc: widget.intent.amountUsdc,
      );
      await _bookings.submitTx(
        paymentId: widget.intent.paymentId,
        txHash: transfer.txHash,
        fromAddress: transfer.fromAddress,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BookingWaitingPage(
            car: widget.car,
            intent: widget.intent,
          ),
        ),
      );
    } on UsdcTransferException catch (e, st) {
      debugPrint('[Qent BookingConfirm] UsdcTransferException: ${e.message}\n$st');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (e, st) {
      debugPrint('[Qent BookingConfirm] ${e.runtimeType}: $e\n$st');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Payment failed: $e';
      });
    }
  }

  Future<void> _cancel() async {
    if (_busy) return;
    // Booking row stays `pending_payment` — next Pay Now tap returns
    // the same intent (idempotent server-side).
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final daysLabel =
        '${widget.intent.totalDays} day${widget.intent.totalDays == 1 ? '' : 's'}';
    final dateFmt = '${_fmtDate(widget.pickupDate)} → ${_fmtDate(widget.returnDate)}';

    return Scaffold(
      backgroundColor: context.bgPrimary,
      appBar: AppBar(
        backgroundColor: context.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.textPrimary),
          onPressed: _busy ? null : _cancel,
        ),
        title: Text(
          'Confirm payment',
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _carSummary(context, daysLabel, dateFmt),
                    const SizedBox(height: 28),
                    _sectionLabel(context, 'Charge breakdown'),
                    const SizedBox(height: 12),
                    _breakdownRow(context, 'Car (\$${_perDay()} × $daysLabel)',
                        '\$${_fmtUsdc(widget.intent.hostPriceUsdc)}'),
                    _breakdownRow(context, 'Service fee',
                        '\$${_fmtUsdc(widget.intent.serviceFeeUsdc)}'),
                    if (_nonZero(widget.intent.protectionPriceUsdc))
                      _breakdownRow(context, 'Protection',
                          '\$${_fmtUsdc(widget.intent.protectionPriceUsdc)}'),
                    const SizedBox(height: 12),
                    Divider(color: context.borderColor, height: 1),
                    const SizedBox(height: 12),
                    _breakdownRow(
                      context,
                      'Total',
                      '\$${_fmtUsdc(widget.intent.totalUsdc)} USDC',
                      bold: true,
                    ),
                    const SizedBox(height: 28),
                    _disclaimerCard(context),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      _errorBanner(_error!),
                    ],
                  ],
                ),
              ),
            ),
            _footer(context),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────

  Widget _carSummary(BuildContext context, String daysLabel, String dateFmt) {
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
              width: 84,
              height: 64,
              child: widget.car.photos.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: widget.car.photos.first,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: context.bgPrimary),
                      errorWidget: (_, __, ___) => Container(
                        color: context.bgPrimary,
                        child: const Icon(Icons.directions_car_rounded,
                            color: Colors.grey),
                      ),
                    )
                  : Container(
                      color: context.bgPrimary,
                      child: const Icon(Icons.directions_car_rounded,
                          color: Colors.grey),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.car.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  dateFmt,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  daysLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: context.textTertiary,
      ),
    );
  }

  Widget _breakdownRow(BuildContext context, String label, String value,
      {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: bold ? 15 : 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: bold ? context.textPrimary : context.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: bold ? 15 : 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _disclaimerCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.inputBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, size: 18, color: context.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your wallet will ask you to approve. The USDC moves to '
              'Qent escrow and is released to the host after the trip.',
              style: TextStyle(
                fontSize: 12,
                color: context.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: Color(0xFFEF4444), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  color: Color(0xFFEF4444), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: context.bgPrimary,
        border: Border(top: BorderSide(color: context.borderColor)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _busy ? null : _payWithWallet,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                context.isDark ? const Color(0xFF22C55E) : const Color(0xFF1A1A1A),
            disabledBackgroundColor:
                (context.isDark ? const Color(0xFF22C55E) : const Color(0xFF1A1A1A))
                    .withValues(alpha: 0.6),
            foregroundColor: context.isDark ? Colors.black : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: _busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined,
                        size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'Pay \$${_fmtUsdc(widget.intent.totalUsdc)} with wallet',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────

  String _perDay() {
    final total = double.tryParse(widget.intent.hostPriceUsdc) ?? 0;
    final days = widget.intent.totalDays == 0 ? 1 : widget.intent.totalDays;
    return (total / days).toStringAsFixed(2);
  }

  // Trim rust_decimal's "365.848000" → "365.85".
  String _fmtUsdc(String raw) =>
      (double.tryParse(raw) ?? 0).toStringAsFixed(2);

  bool _nonZero(String v) => (double.tryParse(v) ?? 0) > 0;

  String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }
}
