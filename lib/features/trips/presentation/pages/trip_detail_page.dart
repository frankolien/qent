import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qent/core/services/api_client.dart';
import 'package:qent/core/widgets/profile_image_widget.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart';
import 'package:qent/features/chat/presentation/controllers/chat_controller.dart';
import 'package:qent/features/chat/presentation/pages/chat_detail_page.dart';
import 'package:qent/features/trips/presentation/pages/trips_page.dart';
import 'package:qent/features/reviews/presentation/pages/leave_review_page.dart';
import 'package:url_launcher/url_launcher.dart';

class TripDetailPage extends ConsumerStatefulWidget {
  final TripBooking trip;

  const TripDetailPage({super.key, required this.trip});

  @override
  ConsumerState<TripDetailPage> createState() => _TripDetailPageState();
}

class _TripDetailPageState extends ConsumerState<TripDetailPage> {
  bool _isCancelling = false;
  bool _isMessaging = false;
  bool _isPerformingAction = false;
  bool _isPaying = false;

  String get _status => widget.trip.status;

  /// Whether the current user is the host of this booking.
  bool get _isHost {
    final currentUserId = ref.read(authControllerProvider).user?.uid ?? '';
    return currentUserId == widget.trip.hostId;
  }

  Future<void> _cancelBooking() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Cancel Booking', style: GoogleFonts.roboto(fontWeight: FontWeight.w700, fontSize: 17)),
        content: Text(
          'Are you sure you want to cancel this booking? This cannot be undone.',
          style: GoogleFonts.roboto(fontSize: 14, color: Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Keep', style: GoogleFonts.roboto(color: Colors.grey[600], fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Cancel Booking', style: GoogleFonts.roboto(color: Colors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isCancelling = true);
    try {
      final response = await ApiClient().post(
        '/bookings/${widget.trip.id}/action',
        body: {'action': 'cancel', 'reason': _isHost ? 'Cancelled by host' : 'Cancelled by renter'},
      );
      if (mounted) {
        if (response.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Booking cancelled'),
              backgroundColor: Colors.grey[800],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          Navigator.of(context).pop(); // Go back to trips list
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.errorMessage),
              backgroundColor: Colors.red[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red[700]),
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Future<void> _initiatePayment() async {
    HapticFeedback.mediumImpact();
    setState(() => _isPaying = true);
    try {
      final response = await ApiClient().post(
        '/payments/initiate',
        body: {'booking_id': widget.trip.id},
      );
      if (!mounted) return;
      if (response.isSuccess) {
        final url = response.body['authorization_url'] as String?;
        if (url != null && url.isNotEmpty) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
          // Poll for status change after returning from browser
          for (int i = 0; i < 5; i++) {
            await Future.delayed(const Duration(seconds: 2));
            if (!mounted) return;
            final check = await ApiClient().get('/bookings/${widget.trip.id}');
            if (check.isSuccess) {
              final status = (check.body as Map<String, dynamic>)['status'] as String?;
              if (status == 'confirmed') {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Payment successful!'),
                      backgroundColor: const Color(0xFF2E7D32),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                  Navigator.of(context).pop();
                }
                return;
              }
            }
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.errorMessage),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Payment failed. Please try again.'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  Future<void> _performHostAction(String action, String confirmTitle, String confirmBody) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(confirmTitle, style: GoogleFonts.roboto(fontWeight: FontWeight.w700, fontSize: 17)),
        content: Text(confirmBody, style: GoogleFonts.roboto(fontSize: 14, color: Colors.grey[700])),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Not yet', style: GoogleFonts.roboto(color: Colors.grey[600], fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Confirm', style: GoogleFonts.roboto(color: const Color(0xFF2E7D32), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    HapticFeedback.mediumImpact();
    setState(() => _isPerformingAction = true);
    try {
      final response = await ApiClient().post(
        '/bookings/${widget.trip.id}/action',
        body: {'action': action},
      );
      if (mounted) {
        if (response.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(action == 'activate' ? 'Trip started — car handed over!' : 'Trip complete — car returned!'),
              backgroundColor: const Color(0xFF2E7D32),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.errorMessage), backgroundColor: Colors.red[700], behavior: SnackBarBehavior.floating),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red[700]),
        );
      }
    } finally {
      if (mounted) setState(() => _isPerformingAction = false);
    }
  }

  Future<void> _messageOtherParty() async {
    setState(() => _isMessaging = true);
    try {
      // Pass the OTHER party's ID — renter if we're the host, host if we're the renter
      final otherUserId = _isHost ? widget.trip.renterId : widget.trip.hostId;
      final chat = await ref.read(chatControllerProvider).getOrCreateConversation(
        widget.trip.carId,
        otherUserId,
      );
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatDetailPage(chat: chat)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Could not open chat'), backgroundColor: Colors.red[700]),
        );
      }
    } finally {
      if (mounted) setState(() => _isMessaging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final formatter = NumberFormat('#,##0', 'en_US');
    final dateFormat = DateFormat('EEE, d MMM yyyy');

    String startStr = trip.startDate;
    String endStr = trip.endDate;
    try {
      startStr = dateFormat.format(DateTime.parse(trip.startDate));
      endStr = dateFormat.format(DateTime.parse(trip.endDate));
    } catch (_) {}

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey[300]!, width: 1),
                ),
                child: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.black),
              ),
            ),
          ),
        ),
        centerTitle: true,
        title: Text('Trip Details', style: GoogleFonts.roboto(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.black)),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Car image
            if (trip.carPhoto != null)
              Image.network(
                trip.carPhoto!,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildImgPlaceholder(),
              )
            else
              _buildImgPlaceholder(),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Car name + status
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          trip.carName,
                          style: GoogleFonts.roboto(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF1A1A1A)),
                        ),
                      ),
                      _buildStatusBadge(),
                    ],
                  ),

                  // Renter info for hosts
                  if (_isHost && trip.renterName != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFD6E4FF)),
                      ),
                      child: Row(
                        children: [
                          ProfileImageWidget(userId: trip.renterId, size: 40),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  trip.renterName!,
                                  style: GoogleFonts.roboto(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Renter',
                                  style: GoogleFonts.roboto(fontSize: 12, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Timeline
                  _buildTimeline(),

                  const SizedBox(height: 24),

                  // Booking details card
                  _buildInfoCard('Booking Details', [
                    _infoRow('Pickup', startStr),
                    _infoRow('Return', endStr),
                    _infoRow('Duration', '${trip.totalDays} day${trip.totalDays == 1 ? '' : 's'}'),
                    if (trip.carLocation != null) _infoRow('Location', trip.carLocation!),
                  ]),

                  const SizedBox(height: 16),

                  // Payment card
                  _buildInfoCard('Payment', [
                    _infoRow('Rate', '\u20a6${formatter.format(trip.pricePerDay.toInt())}/day'),
                    _infoRow('Total', '\u20a6${formatter.format(trip.totalAmount.toInt())}'),
                    _infoRow('Booking ID', '#${trip.id.length > 8 ? trip.id.substring(0, 8) : trip.id}'),
                  ]),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  Widget _buildStatusBadge() {
    final info = _statusStyle(_status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: info.bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        info.label,
        style: GoogleFonts.roboto(fontSize: 13, fontWeight: FontWeight.w600, color: info.textColor),
      ),
    );
  }

  Widget _buildTimeline() {
    final steps = <_TimelineStep>[];

    // Step 1: Booked
    steps.add(_TimelineStep(
      title: 'Booking placed',
      subtitle: 'Request sent to host',
      isDone: true,
    ));

    // Step 2: Host response
    if (_status == 'pending') {
      steps.add(_TimelineStep(
        title: 'Waiting for host',
        subtitle: 'The host will accept or decline',
        isDone: false,
        isCurrent: true,
      ));
    } else if (_status == 'rejected') {
      steps.add(_TimelineStep(
        title: 'Host declined',
        subtitle: 'This booking was not accepted',
        isDone: true,
        isError: true,
      ));
    } else {
      steps.add(_TimelineStep(
        title: 'Host accepted',
        subtitle: 'Booking approved',
        isDone: true,
      ));
    }

    // Step 3: Payment
    if (!['pending', 'rejected', 'cancelled'].contains(_status)) {
      steps.add(_TimelineStep(
        title: _status == 'approved' ? 'Pay now' : 'Payment complete',
        subtitle: _status == 'approved'
            ? 'Complete payment to confirm booking'
            : 'Payment received',
        isDone: ['confirmed', 'active', 'completed'].contains(_status),
        isCurrent: _status == 'approved',
      ));
    }

    // Step 4: Pickup
    if (!['pending', 'rejected', 'cancelled', 'approved'].contains(_status)) {
      steps.add(_TimelineStep(
        title: 'Pickup',
        subtitle: _status == 'confirmed'
            ? 'Coordinate with host'
            : 'Car picked up',
        isDone: ['active', 'completed'].contains(_status),
        isCurrent: _status == 'confirmed',
      ));
    }

    // Step 4: Return
    if (['active', 'completed'].contains(_status)) {
      steps.add(_TimelineStep(
        title: _status == 'completed' ? 'Returned' : 'Return car',
        subtitle: _status == 'completed'
            ? 'Trip complete'
            : 'Return by ${_formatDate(widget.trip.endDate)}',
        isDone: _status == 'completed',
        isCurrent: _status == 'active',
      ));
    }

    // Cancelled
    if (_status == 'cancelled') {
      steps.add(_TimelineStep(
        title: 'Cancelled',
        subtitle: 'This booking was cancelled',
        isDone: true,
        isError: true,
      ));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Trip Timeline', style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
          const SizedBox(height: 16),
          ...List.generate(steps.length, (i) {
            final step = steps[i];
            final isLast = i == steps.length - 1;
            return _buildTimelineItem(step, isLast);
          }),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(_TimelineStep step, bool isLast) {
    final dotColor = step.isError
        ? Colors.red
        : step.isDone
            ? const Color(0xFF4CAF50)
            : step.isCurrent
                ? const Color(0xFF2196F3)
                : Colors.grey[300]!;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dot and line
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                  child: step.isDone
                      ? const Icon(Icons.check, size: 10, color: Colors.white)
                      : step.isCurrent
                          ? Container(
                              margin: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            )
                          : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: step.isDone ? const Color(0xFF4CAF50).withValues(alpha: 0.3) : Colors.grey[200],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: step.isError ? Colors.red[700] : const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    step.subtitle,
                    style: GoogleFonts.roboto(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> rows) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
          const SizedBox(height: 14),
          ...rows,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.roboto(fontSize: 13, color: Colors.grey[500])),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.roboto(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF1A1A1A)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    // Only renters can cancel; hosts use Accept/Decline from the dashboard
    final canCancel = !_isHost && ['pending', 'approved', 'confirmed'].contains(_status);
    final canMessage = !['cancelled', 'rejected'].contains(_status);
    final messageLabel = _isHost ? 'Message Renter' : 'Message Host';
    final canPay = !_isHost && _status == 'approved';

    // Host handover/return actions
    final canConfirmPickup = _isHost && _status == 'confirmed';
    final canConfirmReturn = _isHost && _status == 'active';
    final hasHostAction = canConfirmPickup || canConfirmReturn;
    final canReview = _status == 'completed';

    if (!canCancel && !canMessage && !hasHostAction && !canReview && !canPay) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.only(left: 20, right: 20, top: 14, bottom: bottomPadding + 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, -2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pay Now button (renter, after host approved)
          if (canPay)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isPaying ? null : _initiatePayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A1A),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[400],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isPaying
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.payment_rounded, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Pay Now',
                              style: GoogleFonts.roboto(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          // Host action button (Confirm Pickup / Confirm Return)
          if (hasHostAction)
            Padding(
              padding: EdgeInsets.only(bottom: canMessage ? 10 : 0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isPerformingAction
                      ? null
                      : () {
                          if (canConfirmPickup) {
                            _performHostAction(
                              'activate',
                              'Confirm Pickup',
                              'Confirm that the renter has picked up the car? This will start the trip.',
                            );
                          } else {
                            _performHostAction(
                              'complete',
                              'Confirm Return',
                              'Confirm that the car has been returned? This will complete the trip.',
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[400],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isPerformingAction
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(canConfirmPickup ? Icons.key_rounded : Icons.check_circle_rounded, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              canConfirmPickup ? 'Confirm Pickup' : 'Confirm Return',
                              style: GoogleFonts.roboto(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          // Leave a Review button (completed trips)
          if (canReview)
            Padding(
              padding: EdgeInsets.only(bottom: canMessage ? 10 : 0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final trip = widget.trip;
                    final revieweeId = _isHost ? trip.renterId : trip.hostId;
                    final revieweeName = _isHost ? (trip.renterName ?? 'Renter') : 'Host';
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LeaveReviewPage(
                          bookingId: trip.id,
                          revieweeId: revieweeId,
                          revieweeName: revieweeName,
                          carName: trip.carName,
                          carPhoto: trip.carPhoto,
                          isReviewingHost: !_isHost,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    foregroundColor: const Color(0xFF1A1A1A),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text('Leave a Review', style: GoogleFonts.roboto(fontSize: 15, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
          // Message + Cancel row
          Row(
            children: [
              if (canMessage)
                Expanded(
                  flex: 3,
                  child: ElevatedButton(
                    onPressed: _isMessaging ? null : _messageOtherParty,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1A1A),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[400],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _isMessaging
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.chat_bubble_rounded, size: 18),
                              const SizedBox(width: 8),
                              Text(messageLabel, style: GoogleFonts.roboto(fontSize: 15, fontWeight: FontWeight.w700)),
                            ],
                          ),
                  ),
                ),
              if (canCancel && canMessage) const SizedBox(width: 12),
              if (canCancel)
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    onPressed: _isCancelling ? null : _cancelBooking,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(color: Colors.red[300]!),
                    ),
                    child: _isCancelling
                        ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red[300]))
                        : Text('Cancel', style: GoogleFonts.roboto(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImgPlaceholder() {
    return Container(
      height: 220,
      width: double.infinity,
      color: Colors.grey[100],
      child: Icon(Icons.directions_car_rounded, size: 56, color: Colors.grey[300]),
    );
  }

  String _formatDate(String dateStr) {
    try {
      return DateFormat('d MMM').format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }

  ({String label, Color bgColor, Color textColor}) _statusStyle(String status) {
    return switch (status) {
      'pending' => (label: 'Pending Approval', bgColor: const Color(0xFFFFF3E0), textColor: const Color(0xFFE65100)),
      'approved' => (label: 'Approved — Ready to Pay', bgColor: const Color(0xFFE3F2FD), textColor: const Color(0xFF1565C0)),
      'confirmed' => (label: 'Paid — Awaiting Pickup', bgColor: const Color(0xFFE8F5E9), textColor: const Color(0xFF2E7D32)),
      'active' => (label: 'Trip Active', bgColor: const Color(0xFFE8F5E9), textColor: const Color(0xFF2E7D32)),
      'completed' => (label: 'Trip Completed', bgColor: const Color(0xFFF5F5F5), textColor: const Color(0xFF616161)),
      'cancelled' => (label: 'Cancelled', bgColor: const Color(0xFFFFEBEE), textColor: const Color(0xFFC62828)),
      'rejected' => (label: 'Declined by Host', bgColor: const Color(0xFFFFEBEE), textColor: const Color(0xFFC62828)),
      _ => (label: status, bgColor: Colors.grey[100]!, textColor: Colors.grey[600]!),
    };
  }
}

class _TimelineStep {
  final String title;
  final String subtitle;
  final bool isDone;
  final bool isCurrent;
  final bool isError;

  _TimelineStep({
    required this.title,
    required this.subtitle,
    this.isDone = false,
    this.isCurrent = false,
    this.isError = false,
  });
}
