import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/features/booking/presentation/pages/booking_details_page.dart';
import 'package:qent/features/car_details/domain/models/car_detail.dart';
import 'package:qent/features/home/domain/models/car.dart';
import 'package:qent/features/home/presentation/providers/car_providers.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

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
  }

  void _initializeCarDetail() {
    // Ensure at least 3 images for a scrollable carousel
    var images = widget.car.photos.isNotEmpty
        ? widget.car.photos
        : [widget.car.imageUrl];
    if (images.length < 3 && images.first.isNotEmpty) {
      images = List.generate(3, (_) => images.first);
    }

    // Fixed 6 feature cards matching the Figma design with asset images
    final carFeatures = <CarFeature>[
      CarFeature(
        id: 'seats',
        label: 'Capacity',
        value: '${widget.car.seats} Seats',
        assetImage: 'assets/images/carFeatures/seat.png',
      ),
      CarFeature(
        id: 'engine',
        label: 'Engine Out',
        value: '670 HP',
        assetImage: 'assets/images/carFeatures/engine.png',
      ),
      CarFeature(
        id: 'speed',
        label: 'Max Speed',
        value: '250km/h',
        assetImage: 'assets/images/carFeatures/max_speed.png',
      ),
      CarFeature(
        id: 'autopilot',
        label: 'Advance',
        value: 'Autopilot',
        assetImage: 'assets/images/carFeatures/advanced.png',
      ),
      CarFeature(
        id: 'charge',
        label: 'Single Charge',
        value: '405 Miles',
        assetImage: 'assets/images/carFeatures/miles.png',
      ),
      CarFeature(
        id: 'parking',
        label: 'Advance',
        value: 'Auto Parking',
        assetImage: 'assets/images/carFeatures/auto_parking.png',
      ),
    ];

    _carDetail = CarDetail.fromCar(
      car: widget.car,
      detailDescription: widget.car.description.isNotEmpty
          ? widget.car.description
          : 'A car with high specs that are rented at an affordable price.',
      imageUrls: images,
      host: Host(
        id: widget.car.hostId,
        name: 'Hela Quintin',
        profileImageUrl: '',
        isVerified: true,
      ),
      carFeatures: carFeatures,
      reviews: [
        Review(
          id: '1',
          userName: 'Mr. Jack',
          userImageUrl: '',
          rating: 5.0,
          comment: 'The rental car was clean, reliable, and the service was quick and efficient.',
          date: DateTime.now().subtract(const Duration(days: 3)),
        ),
        Review(
          id: '2',
          userName: 'Robert',
          userImageUrl: '',
          rating: 5.0,
          comment: 'The rental car was clean, reliable, and the service was quick and efficient.',
          date: DateTime.now().subtract(const Duration(days: 7)),
        ),
      ],
      totalReviews: widget.car.tripCount > 0 ? widget.car.tripCount : 125,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    //const SizedBox(height: 8),
                    Divider(color: Colors.grey[200], height: 1),
           
                    _buildImageCarousel(context),
                    const SizedBox(height: 20),
                   
                    //const SizedBox(height: 5),
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
      ),
      bottomNavigationBar: _buildBookNowButton(context),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200, width: 1),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF1A1A1A)),
            ),
          ),
          const Text(
            'Car Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200, width: 1),
              ),
              child: const Icon(Icons.more_horiz_rounded, size: 20, color: Color(0xFF1A1A1A)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCarousel(BuildContext context) {
    return Container(
      //margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 300,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: ClipRRect(
        //borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: _carDetail.imageUrls.length,
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
            // Favorite button overlay
            Positioned(
              top: 14,
              right: 14,
              child: _buildFavoriteButton(context),
            ),
            // Page indicator
            if (_carDetail.imageUrls.length > 1)
              Positioned(
                bottom: 14,
                left: 0,
                right: 0,
                child: Center(
                  child: SmoothPageIndicator(
                    controller: _pageController,
                    count: _carDetail.imageUrls.length,
                    effect: ExpandingDotsEffect(
                      activeDotColor: const Color(0xFF1A1A1A),
                      dotColor: Colors.grey.shade400,
                      dotHeight: 6,
                      dotWidth: 6,
                      spacing: 6,
                      expansionFactor: 3,
                    ),
                  ),
                ),
              ),
          ],
        ),
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
          const SizedBox(height: 8),
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
            onTap: () {},
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
          const SizedBox(height: 16),
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
          // Horizontal scrolling review cards
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
    final carAsync = ref.watch(carProvider(widget.car.id));
    return carAsync.when(
      data: (car) => _buildFavIcon(car?.isFavorite ?? widget.car.isFavorite),
      loading: () => _buildFavIcon(widget.car.isFavorite),
      error: (_, __) => _buildFavIcon(widget.car.isFavorite),
    );
  }

  Widget _buildFavIcon(bool isFavorite) {
    return GestureDetector(
      onTap: () => ref.read(carControllerProvider).toggleFavorite(widget.car.id),
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
