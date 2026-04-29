import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qent/features/booking/domain/models/booking_confirmation.dart';
import 'package:qent/features/chat/presentation/controllers/chat_controller.dart';
import 'package:qent/features/chat/presentation/pages/chat_detail_page.dart';
import 'package:qent/features/home/domain/models/car.dart';
import 'package:qent/core/theme/app_theme.dart';

class PaymentStatesPage extends ConsumerStatefulWidget {
  final Car car;
  final BookingConfirmation confirmation;

  const PaymentStatesPage({
    super.key,
    required this.car,
    required this.confirmation,
  });

  @override
  ConsumerState<PaymentStatesPage> createState() => _PaymentStatesPageState();
}

class _PaymentStatesPageState extends ConsumerState<PaymentStatesPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  bool _isMessageLoading = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String _formatDateRange() {
    final dateFormat = DateFormat('d MMM yy');
    return '${dateFormat.format(widget.confirmation.pickupDate)} - ${dateFormat.format(widget.confirmation.returnDate)}';
  }

  String _formatTransactionDate() {
    final now = DateTime.now();
    return '${DateFormat('d MMM yyyy').format(now)} - ${DateFormat('hh:mm a').format(now)}';
  }

  String _formatAmount(double amount) {
    final formatter = NumberFormat('#,##0', 'en_US');
    return '\u20a6${formatter.format(amount.toInt())}';
  }

  Future<void> _messageHost() async {
    setState(() => _isMessageLoading = true);
    try {
      final chat = await ref.read(chatControllerProvider).getOrCreateConversation(
        widget.car.id,
        widget.car.hostId,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChatDetailPage(chat: chat)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not open chat. Please try from Messages.'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isMessageLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: context.bgPrimary,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Minimal header — no back button (they should go home or message host)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Text(
                  'Booking Confirmed',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                  child: Column(
                    children: [
                      const SizedBox(height: 36),
                      _buildAnimatedSuccessIcon(),
                      const SizedBox(height: 24),
                      _buildSuccessMessage(),
                      const SizedBox(height: 28),
                      _buildWhatsNextCard(),
                      const SizedBox(height: 24),
                      _buildBookingInfoCard(),
                      const SizedBox(height: 16),
                      _buildTransactionCard(),
                      const SizedBox(height: 28),
                      _buildReceiptActions(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              _buildBottomActions(screenWidth, bottomPadding),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedSuccessIcon() {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  color: Color(0xFF4CAF50),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 40),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSuccessMessage() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          Text(
            'You\'re all set!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your ${widget.car.name} booking is confirmed',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: context.textTertiary, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildWhatsNextCard() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FAF0),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.route_rounded, size: 18, color: Color(0xFF2E7D32)),
                ),
                const SizedBox(width: 10),
                Text(
                  'What\'s Next',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStep(
              number: '1',
              title: 'Host has been notified',
              subtitle: 'They\'ll confirm pickup details shortly',
              isDone: true,
            ),
            _buildStep(
              number: '2',
              title: 'Confirmation email sent',
              subtitle: 'Check your inbox for the receipt',
              isDone: true,
            ),
            _buildStep(
              number: '3',
              title: 'Message your host',
              subtitle: 'Coordinate pickup time and location',
              isDone: false,
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep({
    required String number,
    required String title,
    required String subtitle,
    required bool isDone,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isDone ? const Color(0xFF4CAF50) : context.bgPrimary,
              shape: BoxShape.circle,
              border: isDone
                  ? null
                  : Border.all(color: const Color(0xFF4CAF50), width: 2),
            ),
            child: Center(
              child: isDone
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : Text(
                      number,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDone ? const Color(0xFF1A1A1A) : const Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: context.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.bgSecondary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Booking Details',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Car', widget.car.name),
          const SizedBox(height: 10),
          _buildInfoRow('Dates', _formatDateRange()),
          const SizedBox(height: 10),
          _buildInfoRow('Booking ID', widget.confirmation.bookingId.length > 8
              ? '#${widget.confirmation.bookingId.substring(0, 8)}'
              : '#${widget.confirmation.bookingId}'),
        ],
      ),
    );
  }

  Widget _buildTransactionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.bgSecondary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Summary',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
          ),
          const SizedBox(height: 16),
          if (widget.confirmation.paymentReference != null) ...[
            _buildInfoRow('Reference', widget.confirmation.paymentReference!),
            const SizedBox(height: 10),
          ],
          _buildInfoRow('Date', _formatTransactionDate()),
          const SizedBox(height: 10),
          _buildInfoRow('Method', widget.confirmation.paymentMethod),
          const SizedBox(height: 10),
          _buildInfoRow('Subtotal', _formatAmount(widget.confirmation.amount)),
          const SizedBox(height: 10),
          _buildInfoRow('Service fee', _formatAmount(widget.confirmation.serviceFee)),
          if (widget.confirmation.protectionFee > 0) ...[
            const SizedBox(height: 10),
            _buildInfoRow('Protection', _formatAmount(widget.confirmation.protectionFee)),
          ],
          const SizedBox(height: 10),
          Divider(color: context.borderColor, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
              ),
              Text(
                _formatAmount(widget.confirmation.totalAmount),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: context.textTertiary)),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptActions() {
    return Row(
      children: [
        Expanded(
          child: _buildSmallAction(
            icon: Icons.download_rounded,
            label: 'Download',
            onTap: () {},
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSmallAction(
            icon: Icons.share_rounded,
            label: 'Share',
            onTap: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildSmallAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: context.bgSecondary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: context.textSecondary, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions(double screenWidth, double bottomPadding) {
    return Container(
      padding: EdgeInsets.only(
        left: screenWidth * 0.05,
        right: screenWidth * 0.05,
        top: 14,
        bottom: bottomPadding + 14,
      ),
      decoration: BoxDecoration(
        color: context.bgPrimary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Message Host — primary action
          Expanded(
            flex: 3,
            child: ElevatedButton(
              onPressed: _isMessageLoading ? null : _messageHost,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.isDark ? context.accent : const Color(0xFF1A1A1A),
                foregroundColor: context.isDark ? Colors.black : Colors.white,
                disabledBackgroundColor: Colors.grey[400],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _isMessageLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_rounded, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Message Host',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Back to Home — secondary
          Expanded(
            flex: 2,
            child: OutlinedButton(
              onPressed: () {
                Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: context.textPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                side: BorderSide(color: context.borderColor),
              ),
              child: const Text(
                'Home',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
