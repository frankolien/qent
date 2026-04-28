import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/core/theme/app_theme.dart';
import 'package:qent/features/car_details/domain/models/car_detail.dart';
import 'package:qent/features/car_details/presentation/providers/car_reviews_provider.dart';

class ReviewsPage extends ConsumerStatefulWidget {
  final String carId;
  final VoidCallback? onBookNow;

  const ReviewsPage({
    super.key,
    required this.carId,
    this.onBookNow,
  });

  @override
  ConsumerState<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends ConsumerState<ReviewsPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final reviewsAsync = ref.watch(carReviewsProvider(widget.carId));

    return Scaffold(
      backgroundColor: context.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Divider(color: context.dividerColor, height: 1),
            Expanded(
              child: reviewsAsync.when(
                data: (reviews) {
                  final filtered = _query.isEmpty
                      ? reviews
                      : reviews
                          .where((r) =>
                              r.userName
                                  .toLowerCase()
                                  .contains(_query.toLowerCase()) ||
                              r.comment
                                  .toLowerCase()
                                  .contains(_query.toLowerCase()))
                          .toList();
                  return _buildList(context, reviews, filtered);
                },
                loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
                error: (e, _) => _buildError(e.toString()),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: widget.onBookNow != null
          ? _buildBookNow(context)
          : null,
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: context.isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : const Color(0xFFE5E5E5),
                ),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  size: 16, color: context.textPrimary),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Reviews',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
            ),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: context.isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : const Color(0xFFE5E5E5),
              ),
            ),
            child: Icon(Icons.more_horiz, size: 18, color: context.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<Review> all,
    List<Review> filtered,
  ) {
    final avg = all.isEmpty
        ? 0.0
        : all.map((r) => r.rating).reduce((a, b) => a + b) / all.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      physics: const BouncingScrollPhysics(),
      children: [
        Row(
          children: [
            const Icon(Icons.star_rounded,
                color: Color(0xFFFFB800), size: 22),
            const SizedBox(width: 6),
            Text(
              '${avg.toStringAsFixed(1)} Reviews (${all.length})',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSearchField(context),
        const SizedBox(height: 16),
        if (all.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text('No reviews yet',
                  style: TextStyle(color: Colors.grey[500])),
            ),
          )
        else if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text('No reviews match your search',
                  style: TextStyle(color: Colors.grey[500])),
            ),
          )
        else
          ...filtered.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ReviewCard(review: r),
              )),
      ],
    );
  }

  Widget _buildSearchField(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.bgPrimary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE5E5E5),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 20, color: Colors.grey[500]),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: TextStyle(fontSize: 14, color: context.textPrimary),
              decoration: InputDecoration(
                hintText: 'Find reviews...',
                hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.grey[500], size: 48),
            const SizedBox(height: 12),
            Text('Could not load reviews',
                style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  ref.invalidate(carReviewsProvider(widget.carId)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookNow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).pop();
          widget.onBookNow?.call();
        },
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(40),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text('Book Now',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              SizedBox(width: 10),
              Icon(Icons.arrow_forward, color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Review review;
  const _ReviewCard({required this.review});

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} weeks ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} months ago';
    return '${(diff.inDays / 365).floor()} years ago';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.bgPrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE8E8E8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[300],
                ),
                child: ClipOval(
                  child: review.userImageUrl.isNotEmpty
                      ? Image.network(review.userImageUrl, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Icon(Icons.person, size: 20, color: Colors.grey[500]))
                      : Icon(Icons.person, size: 20, color: Colors.grey[500]),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  review.userName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
              ),
              Text(
                _timeAgo(review.date),
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (i) {
              final filled = i < review.rating.round();
              return Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Icon(
                  filled ? Icons.star_rounded : Icons.star_rounded,
                  color: filled ? const Color(0xFFFFB800) : Colors.grey[300],
                  size: 18,
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Text(
            review.comment.isEmpty ? '—' : review.comment,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
