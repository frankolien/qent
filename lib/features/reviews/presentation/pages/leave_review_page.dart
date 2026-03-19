import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qent/core/services/api_client.dart';
import 'package:qent/core/widgets/profile_image_widget.dart';

class LeaveReviewPage extends ConsumerStatefulWidget {
  final String bookingId;
  final String revieweeId;
  final String revieweeName;
  final String carName;
  final String? carPhoto;
  final bool isReviewingHost; // true = renter reviewing host, false = host reviewing renter

  const LeaveReviewPage({
    super.key,
    required this.bookingId,
    required this.revieweeId,
    required this.revieweeName,
    required this.carName,
    this.carPhoto,
    this.isReviewingHost = true,
  });

  @override
  ConsumerState<LeaveReviewPage> createState() => _LeaveReviewPageState();
}

class _LeaveReviewPageState extends ConsumerState<LeaveReviewPage> {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a rating'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    final response = await ApiClient().post('/reviews', body: {
      'booking_id': widget.bookingId,
      'reviewee_id': widget.revieweeId,
      'rating': _rating,
      'comment': _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
    });

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (response.isSuccess) {
      HapticFeedback.heavyImpact();
      _showSuccessDialog();
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

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, size: 36, color: Color(0xFF2E7D32)),
              ),
              const SizedBox(height: 20),
              Text(
                'Thank You!',
                style: GoogleFonts.roboto(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF1A1A1A)),
              ),
              const SizedBox(height: 8),
              Text(
                'Your review helps the Qent community.',
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(fontSize: 14, color: Colors.grey[500], height: 1.5),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pop(true); // Return true = review submitted
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A1A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text('Done', style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
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
          title: Text('Leave a Review', style: GoogleFonts.roboto(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.black)),
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 12),

              // Car photo
              if (widget.carPhoto != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.network(
                    widget.carPhoto!,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _photoPlaceholder(),
                  ),
                )
              else
                _photoPlaceholder(),

              const SizedBox(height: 24),

              // Car name
              Text(
                widget.carName,
                style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF1A1A1A)),
              ),
              const SizedBox(height: 6),

              // Reviewee
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ProfileImageWidget(userId: widget.revieweeId, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    widget.isReviewingHost ? 'Rate your host: ' : 'Rate your renter: ',
                    style: GoogleFonts.roboto(fontSize: 13, color: Colors.grey[500]),
                  ),
                  Text(
                    widget.revieweeName,
                    style: GoogleFonts.roboto(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A)),
                  ),
                ],
              ),

              const SizedBox(height: 36),

              // Star rating
              Text(
                'How was your experience?',
                style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final starIndex = i + 1;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _rating = starIndex);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: AnimatedScale(
                        scale: _rating >= starIndex ? 1.15 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          _rating >= starIndex ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 48,
                          color: _rating >= starIndex ? const Color(0xFFFFC107) : Colors.grey[300],
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Text(
                _ratingLabel(),
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _rating > 0 ? const Color(0xFF1A1A1A) : Colors.grey[400],
                ),
              ),

              const SizedBox(height: 36),

              // Comment
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Write a comment (optional)',
                  style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _commentController,
                maxLines: 4,
                maxLength: 500,
                textInputAction: TextInputAction.done,
                style: GoogleFonts.roboto(fontSize: 14),
                decoration: InputDecoration(
                  hintText: widget.isReviewingHost
                      ? 'How was the car? Was the host responsive?'
                      : 'How was the renter? Was the car returned in good condition?',
                  hintStyle: GoogleFonts.roboto(fontSize: 13, color: Colors.grey[400]),
                  filled: true,
                  fillColor: const Color(0xFFF8F8F8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF1A1A1A), width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.all(18),
                  counterStyle: GoogleFonts.roboto(fontSize: 11, color: Colors.grey[400]),
                ),
              ),

              const SizedBox(height: 36),

              // Submit
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReview,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A1A),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[400],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'Submit Review',
                          style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _ratingLabel() {
    return switch (_rating) {
      1 => 'Terrible',
      2 => 'Poor',
      3 => 'Average',
      4 => 'Good',
      5 => 'Excellent!',
      _ => 'Tap a star to rate',
    };
  }

  Widget _photoPlaceholder() {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(Icons.directions_car_rounded, size: 48, color: Colors.grey[300]),
    );
  }
}
