import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qent/features/booking/domain/models/booking_confirmation.dart';
import 'package:qent/features/booking/presentation/pages/payment_states_page.dart';
import 'package:qent/features/home/domain/models/car.dart';

class ConfirmationPage extends StatelessWidget {
  final Car car;
  final BookingConfirmation confirmation;

  ConfirmationPage({
    super.key,
    required this.car,
    required this.confirmation,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
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
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.arrow_back_rounded, size: 20, color: Color(0xFF1A1A1A)),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Confirmation',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
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
              Expanded(child: Container(height: 2, color: const Color(0xFF1A1A1A))),
              _buildStepCircle(1, activeStep),
              Expanded(child: Container(height: 2, color: const Color(0xFF1A1A1A))),
              _buildStepCircle(2, activeStep),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Details', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: Colors.grey[500])),
              Text('Payment', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: Colors.grey[500])),
              Text('Confirm', style: TextStyle(fontSize: 11, fontWeight: activeStep == 2 ? FontWeight.w600 : FontWeight.w400, color: activeStep == 2 ? const Color(0xFF1A1A1A) : Colors.grey[500])),
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
        color: (isActive || isCompleted) ? const Color(0xFF1A1A1A) : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: (isActive || isCompleted) ? const Color(0xFF1A1A1A) : Colors.grey[300]!,
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
            color: const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(20),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: car.imageUrl.isNotEmpty
                ? Image.network(
                    car.imageUrl,
                    fit: BoxFit.cover,
                    frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                      if (wasSynchronouslyLoaded) return child;
                      return AnimatedOpacity(
                        opacity: frame == null ? 0 : 1,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        child: child,
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: const Color(0xFFF0F0F0),
                        child: const Center(
                          child: Icon(Icons.directions_car_rounded, size: 64, color: Colors.grey),
                        ),
                      );
                    },
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
                    car.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A car with high specs that are rented at an affordable price.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
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
                      car.rating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
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
                    color: Colors.grey[500],
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
        const Text(
          'Booking Information',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 16),
        _buildInfoRow('Booking ID', confirmation.bookingId),
        const SizedBox(height: 12),
        _buildInfoRow('Name', confirmation.customerName),
        const SizedBox(height: 12),
        _buildInfoRow(
          'Pick up Date',
          _formatDateTime(confirmation.pickupDate, confirmation.pickupTime),
        ),
        const SizedBox(height: 12),
        _buildInfoRow(
          'Return Date',
          _formatDateTime(confirmation.returnDate, confirmation.returnTime),
        ),
        const SizedBox(height: 12),
        _buildInfoRowWithIcon(
          'Location',
          confirmation.location,
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
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1A1A1A),
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
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF1A1A1A)),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ],
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

  Widget _buildPaymentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 16),
        _buildInfoRow('Trx ID', confirmation.transactionId),
        const SizedBox(height: 12),
        _buildInfoRow('Amount', '₦${confirmation.amount.toInt()}'),
        const SizedBox(height: 12),
        _buildInfoRow('Service fee', '₦${confirmation.serviceFee.toInt()}'),
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
            const Text(
              'Total amount',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            Row(
              children: [
                Text(
                  '₦${confirmation.totalAmount.toInt()}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(width: 8),
                _buildMastercardLogo(),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Payment with',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMastercardLogo() {
    return Container(
      width: 32,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 8,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
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
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentStatesPage(
                car: car,
                confirmation: confirmation,
              ),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A1A1A),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: const Text(
          'Confirm',
          style: TextStyle(
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
