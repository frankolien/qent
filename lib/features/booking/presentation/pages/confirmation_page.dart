import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qent/core/services/api_client.dart';
import 'package:qent/core/theme/app_theme.dart';
import 'package:qent/features/booking/domain/models/booking_confirmation.dart';
import 'package:qent/features/booking/presentation/pages/payment_states_page.dart';
import 'package:qent/features/home/domain/models/car.dart';
import 'package:url_launcher/url_launcher.dart';

class ConfirmationPage extends StatefulWidget {
  final Car car;
  final BookingConfirmation confirmation;
  final String? authorizationUrl;

  const ConfirmationPage({
    super.key,
    required this.car,
    required this.confirmation,
    this.authorizationUrl,
  });

  @override
  State<ConfirmationPage> createState() => _ConfirmationPageState();
}

class _ConfirmationPageState extends State<ConfirmationPage> {
  bool _isLoading = false;

  Future<void> _handleConfirm() async {
    setState(() => _isLoading = true);

    try {
      // If there's a Paystack authorization URL, open it in browser
      if (widget.authorizationUrl != null && widget.authorizationUrl!.isNotEmpty) {
        final url = Uri.parse(widget.authorizationUrl!);
        await launchUrl(url, mode: LaunchMode.externalApplication);

        // After returning from browser, poll booking status
        if (!mounted) return;
        await _pollBookingStatus();
      } else {
        // For non-Paystack methods, call approve action directly
        final response = await ApiClient().post(
          '/bookings/${widget.confirmation.bookingId}/action',
          body: {'action': 'approve'},
        );

        if (!mounted) return;

        if (response.isSuccess) {
          _navigateToSuccess();
        } else {
          _showError(response.errorMessage);
        }
      }
    } catch (e) {
      if (mounted) _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pollBookingStatus() async {
    // Check booking status after returning from Paystack
    for (int i = 0; i < 5; i++) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      final response = await ApiClient().get(
        '/bookings/${widget.confirmation.bookingId}',
      );

      if (response.isSuccess) {
        final status = (response.body as Map<String, dynamic>)['status'] as String?;
        if (status == 'confirmed' || status == 'approved') {
          _navigateToSuccess();
          return;
        }
      }
    }

    // If polling didn't find confirmed status, navigate anyway with current data
    if (mounted) _navigateToSuccess();
  }

  void _navigateToSuccess() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentStatesPage(
          car: widget.car,
          confirmation: widget.confirmation,
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: context.bgPrimary,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context),
            _buildStepper(activeStep: 2),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _buildCarInformationSection(),
                    const SizedBox(height: 24),
                    _buildBookingInformationalSection(),
                    const SizedBox(height: 24),
                    _buildPaymentSection(),
                    SizedBox(height: screenHeight * 0.15),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildConfirmButton(context, screenWidth),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: context.bgSecondary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.arrow_back_rounded, size: 20, color: context.textPrimary),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Confirmation',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 42),
        ],
      ),
    );
  }

  Widget _buildStepper({required int activeStep}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Column(
        children: [
          Row(
            children: [
              _buildStepCircle(0, activeStep),
              Expanded(child: Container(height: 2, color: context.textPrimary)),
              _buildStepCircle(1, activeStep),
              Expanded(child: Container(height: 2, color: context.textPrimary)),
              _buildStepCircle(2, activeStep),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Details', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: context.textTertiary)),
              Text('Payment', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: context.textTertiary)),
              Text('Confirm', style: TextStyle(fontSize: 11, fontWeight: activeStep == 2 ? FontWeight.w600 : FontWeight.w400, color: activeStep == 2 ? context.textPrimary : context.textTertiary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepCircle(int step, int activeStep) {
    final isCompleted = step < activeStep;
    final isActive = step == activeStep;

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: (isActive || isCompleted) ? context.textPrimary : context.bgPrimary,
        shape: BoxShape.circle,
        border: Border.all(
          color: (isActive || isCompleted) ? context.textPrimary : context.borderColor,
          width: 2,
        ),
      ),
      child: Center(
        child: isCompleted
            ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
            : Text(
                '${step + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : Colors.grey[500],
                ),
              ),
      ),
    );
  }

  Widget _buildCarInformationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: context.bgSecondary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: widget.car.imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: widget.car.imageUrl,
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 300),
                    fadeInCurve: Curves.easeOut,
                    placeholder: (_, __) => Container(
                      color: context.bgSecondary,
                      child: const Center(
                        child: Icon(Icons.directions_car_rounded, size: 64, color: Colors.grey),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: context.bgSecondary,
                      child: const Center(
                        child: Icon(Icons.directions_car_rounded, size: 64, color: Colors.grey),
                      ),
                    ),
                  )
                : const Center(
                    child: Icon(Icons.directions_car_rounded, size: 64, color: Colors.grey),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.car.name,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A car with high specs that are rented at an affordable price.',
                    style: TextStyle(
                      fontSize: 14,
                      color: context.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Text(
                      widget.car.rating.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 20),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '(100+ Reviews)',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textTertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBookingInformationalSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Booking Information',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        _buildInfoRow('Booking ID', widget.confirmation.bookingId.length > 8
            ? '#${widget.confirmation.bookingId.substring(0, 8)}'
            : '#${widget.confirmation.bookingId}'),
        const SizedBox(height: 12),
        _buildInfoRow('Name', widget.confirmation.customerName),
        const SizedBox(height: 12),
        if (widget.confirmation.email.isNotEmpty) ...[
          _buildInfoRow('Email', widget.confirmation.email),
          const SizedBox(height: 12),
        ],
        _buildInfoRow(
          'Pick up Date',
          _formatDateTime(widget.confirmation.pickupDate, widget.confirmation.pickupTime),
        ),
        const SizedBox(height: 12),
        _buildInfoRow(
          'Return Date',
          _formatDateTime(widget.confirmation.returnDate, widget.confirmation.returnTime),
        ),
        const SizedBox(height: 12),
        _buildInfoRowWithIcon(
          'Location',
          widget.confirmation.location,
          Icons.location_on_rounded,
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: context.textPrimary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: context.textSecondary,
              ),
            ),
          ],
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: context.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRowWithIcon(String label, String value, IconData icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: context.textPrimary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: context.textSecondary,
              ),
            ),
          ],
        ),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: context.textPrimary),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  value,
                  style:  TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: context.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime date, TimeOfDay time) {
    final dateFormat = DateFormat('d MMM yyyy');
    final timeString = _formatTime(time);
    return '${dateFormat.format(date)} $timeString';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'pm' : 'am';
    return '$hour:$minute $period';
  }

  String _formatAmount(double amount) {
    final formatter = NumberFormat('#,##0', 'en_US');
    return '\u20a6${formatter.format(amount.toInt())}';
  }

  Widget _buildPaymentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        if (widget.confirmation.paymentReference != null)
          ...[
            _buildInfoRow('Reference', widget.confirmation.paymentReference!),
            const SizedBox(height: 12),
          ],
        _buildInfoRow('Amount', _formatAmount(widget.confirmation.amount)),
        const SizedBox(height: 12),
        _buildInfoRow('Service fee', _formatAmount(widget.confirmation.serviceFee)),
        if (widget.confirmation.protectionFee > 0) ...[
          const SizedBox(height: 12),
          _buildInfoRow('Protection fee', _formatAmount(widget.confirmation.protectionFee)),
        ],
        const SizedBox(height: 12),
        CustomPaint(
          painter: DashedLinePainter(),
          child: const SizedBox(
            width: double.infinity,
            height: 1,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total amount',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
            ),
            Text(
              _formatAmount(widget.confirmation.totalAmount),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Payment with ${widget.confirmation.paymentMethod}',
              style: TextStyle(
                fontSize: 12,
                color: context.textTertiary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConfirmButton(BuildContext context, double screenWidth) {
    return Container(
      padding: EdgeInsets.only(
        left: screenWidth * 0.05,
        right: screenWidth * 0.05,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: context.bgPrimary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleConfirm,
        style: ElevatedButton.styleFrom(
          backgroundColor: context.isDark ? context.accent : const Color(0xFF1A1A1A),
          foregroundColor: context.isDark ? Colors.black : Colors.white,
          disabledBackgroundColor: Colors.grey[400],
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                widget.authorizationUrl != null ? 'Pay Now' : 'Confirm',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

class DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const dashWidth = 4.0;
    const dashSpace = 4.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + dashWidth, 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
