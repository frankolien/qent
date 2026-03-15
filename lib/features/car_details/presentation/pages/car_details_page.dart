import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/core/services/api_client.dart';
import 'package:qent/features/booking/presentation/pages/booking_details_page.dart';
import 'package:qent/features/car_details/domain/models/car_detail.dart';
import 'package:qent/features/chat/presentation/controllers/chat_controller.dart';
import 'package:qent/features/chat/presentation/pages/chat_detail_page.dart';
import 'package:qent/features/home/domain/models/car.dart';
import 'package:qent/features/home/presentation/providers/car_providers.dart';

class CarDetailsPage extends ConsumerStatefulWidget {
  final Car car;

  const CarDetailsPage({
    super.key,
    required this.car,
  });

  @override
  ConsumerState<CarDetailsPage> createState() => _CarDetailsPageState();
}

class _CarDetailsPageState extends ConsumerState<CarDetailsPage> {
  final PageController _pageController = PageController();
  late CarDetail _carDetail;

  @override
  void initState() {
    super.initState();
    _initializeCarDetail();
    _trackView();
  }

  void _trackView() {
    // Fire and forget - track view count
    ApiClient().post('/cars/${widget.car.id}/view', auth: false);
  }

  void _initializeCarDetail() {
    // Use actual car photos
    var images = widget.car.photos.isNotEmpty
        ? widget.car.photos
        : (widget.car.imageUrl.isNotEmpty ? [widget.car.imageUrl] : <String>[]);

    // Build feature cards from actual car data
    final carFeatures = <CarFeature>[
      CarFeature(
        id: 'seats',
        label: 'Capacity',
        value: '${widget.car.seats} Seats',
        assetImage: 'assets/images/carFeatures/seat.png',
      ),
      CarFeature(
        id: 'year',
        label: 'Model Year',
        value: '${widget.car.year}',
        assetImage: 'assets/images/carFeatures/engine.png',
      ),
      CarFeature(
        id: 'color',
        label: 'Color',
        value: widget.car.color.isNotEmpty ? widget.car.color : 'N/A',
        assetImage: 'assets/images/carFeatures/advanced.png',
      ),
      // Add actual features from the car listing
      ...widget.car.features.take(3).map((f) => CarFeature(
            id: f.toLowerCase().replaceAll(' ', '_'),
            label: 'Feature',
            value: f,
            assetImage: 'assets/images/carFeatures/auto_parking.png',
          )),
    ];

    _carDetail = CarDetail.fromCar(
      car: widget.car,
      detailDescription: widget.car.description.isNotEmpty
          ? widget.car.description
          : 'Quality car available for rent.',
      imageUrls: images,
      host: Host(
        id: widget.car.hostId,
        name: widget.car.hostName.isNotEmpty ? widget.car.hostName : 'Host',
        profileImageUrl: '',
        isVerified: false,
      ),
      carFeatures: carFeatures,
      reviews: [],
      totalReviews: widget.car.tripCount,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildImageCarousel(context, topPadding),
                  const SizedBox(height: 20),
                  _buildCarInfo(context),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(color: Colors.grey[200], height: 1),
                  ),
                  const SizedBox(height: 20),
                  _buildHostSection(context),
                  const SizedBox(height: 28),
                  _buildFeaturesSection(context),
                  const SizedBox(height: 28),
                  _buildReviewsSection(context),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBookNowButton(context),
    );
  }

  Widget _buildImageCarousel(BuildContext context, double topPadding) {
    final screenWidth = MediaQuery.of(context).size.width;
    final imageHeight = screenWidth * 0.95; // Nearly square, tall like Airbnb

    return SizedBox(
      height: imageHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Full-bleed image carousel
          PageView.builder(
            controller: _pageController,
            itemCount: _carDetail.imageUrls.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              final url = _carDetail.imageUrls[index];
              return url.startsWith('http')
                  ? Image.network(
                      url,
                      fit: BoxFit.cover,
                      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                        if (wasSynchronouslyLoaded) return child;
                        return AnimatedOpacity(
                          opacity: frame != null ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          child: child,
                        );
                      },
                      errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
                    )
                  : _buildImagePlaceholder();
            },
          ),

          // Back button — top left
          Positioned(
            top: topPadding + 10,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.arrow_back, size: 20, color: Color(0xFF1A1A1A)),
              ),
            ),
          ),

          // Share + Favorite — top right
          Positioned(
            top: topPadding + 10,
            right: 16,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.ios_share_rounded, size: 18, color: Color(0xFF1A1A1A)),
                  ),
                ),
                const SizedBox(width: 10),
                _buildFavoriteButton(context),
              ],
            ),
          ),

          // Photo counter — bottom right "1 / 30" style
          if (_carDetail.imageUrls.length > 1)
            Positioned(
              bottom: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_currentPage + 1} / ${_carDetail.imageUrls.length}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

          // Bottom white curve overlay
          Positioned(
            bottom: -1,
            left: 0,
            right: 0,
            child: Container(
              height: 20,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(60)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: const Color(0xFFF0F0F0),
      child: Center(child: Icon(Icons.directions_car_rounded, size: 80, color: Colors.grey[300])),
    );
  }

  Widget _buildCarInfo(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Car name
          Text(
            _carDetail.name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
              letterSpacing: -0.3,
            ),
          ),
          //const SizedBox(height: 8),
          // Description and rating row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _carDetail.detailDescription,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _carDetail.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 20),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '(${_carDetail.totalReviews}+Reviews)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHostSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Host avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[200],
            ),
            child: ClipOval(
              child: _carDetail.host.profileImageUrl.isNotEmpty
                  ? Image.network(_carDetail.host.profileImageUrl, fit: BoxFit.cover)
                  : Icon(Icons.person, size: 28, color: Colors.grey[400]),
            ),
          ),
          const SizedBox(width: 12),
          // Host name + verified
          Expanded(
            child: Row(
              children: [
                Text(
                  _carDetail.host.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                if (_carDetail.host.isVerified) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.verified, size: 18, color: Color(0xFF2196F3)),
                ],
              ],
            ),
          ),
          // Call button
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200, width: 1),
              ),
              child: Center(
                child: Image.asset(
                  'assets/images/carFeatures/call.png',
                  width: 20,
                  height: 20,
                  errorBuilder: (_, __, ___) => const Icon(Icons.phone_outlined, size: 18, color: Color(0xFF1A1A1A)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Message button
          GestureDetector(
            onTap: () async {
              final chatCtrl = ref.read(chatControllerProvider);
              try {
                final chat = await chatCtrl.getOrCreateConversation(
                  widget.car.id,
                  _carDetail.host.id,
                );
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatDetailPage(chat: chat),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not start chat: $e')),
                );
              }
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color:  Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200, width: 1),
              ),
              child: Center(
                child: Image.asset(
                  'assets/images/carFeatures/message.png',
                  width: 20,
                  height: 20,
                  errorBuilder: (_, __, ___) => const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Color(0xFF1A1A1A)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20,),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Car features',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          //const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.95,
            ),
            itemCount: _carDetail.carFeatures.length,
            itemBuilder: (context, index) => _buildFeatureCard(_carDetail.carFeatures[index]),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(CarFeature feature) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon container
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: feature.assetImage != null
                  ? Image.asset(
                      feature.assetImage!,
                      width: 22,
                      height: 22,
                      errorBuilder: (_, __, ___) => Icon(
                        feature.icon ?? Icons.check_circle_outline,
                        size: 20,
                        color: const Color(0xFF1A1A1A),
                      ),
                    )
                  : Icon(
                      feature.icon ?? Icons.check_circle_outline,
                      size: 20,
                      color: const Color(0xFF1A1A1A),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          // Label
          Text(
            feature.label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          // Value
          Text(
            feature.value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection(BuildContext context) {
    final reviewCount = _carDetail.totalReviews;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Review ($reviewCount)',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: Text(
                  'See All',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[400],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_carDetail.reviews.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No reviews yet',
                style: TextStyle(fontSize: 14, color: Colors.grey[400]),
              ),
            )
          else
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _carDetail.reviews.length,
                itemBuilder: (context, index) {
                  final review = _carDetail.reviews[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      right: index < _carDetail.reviews.length - 1 ? 12 : 0,
                    ),
                    child: _buildReviewCard(review),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Review review) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: avatar, name, rating
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
                      ? Image.network(review.userImageUrl, fit: BoxFit.cover)
                      : Icon(Icons.person, size: 20, color: Colors.grey[400]),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  review.userName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              Text(
                review.rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(width: 3),
              const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFFB800)),
            ],
          ),
          const SizedBox(height: 12),
          // Review text
          Expanded(
            child: Text(
              review.comment,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
                height: 1.5,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteButton(BuildContext context) {
    final favIds = ref.watch(favoriteIdsProvider);
    final isFavorite = favIds.contains(widget.car.id);
    return _buildFavIcon(isFavorite);
  }

  Widget _buildFavIcon(bool isFavorite) {
    return GestureDetector(
      onTap: () => ref.read(favoriteIdsProvider.notifier).toggle(widget.car.id),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          isFavorite ? Icons.favorite : Icons.favorite_border,
          size: 20,
          color: isFavorite ? Colors.red : Colors.grey[400],
        ),
      ),
    );
  }

  Widget _buildBookNowButton(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => BookingDetailsPage(car: widget.car)),
          );
        },
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Book Now',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 10),
              Icon(Icons.arrow_forward_rounded, size: 20, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
