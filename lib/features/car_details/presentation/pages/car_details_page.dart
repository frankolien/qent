import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart';
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
    _carDetail = CarDetail.fromCar(
      car: widget.car,
      description: 'A car with high specs that are rented at an affordable price.',
      imageUrls: [
        widget.car.imageUrl,
        widget.car.imageUrl, 
        widget.car.imageUrl,
      ],
      host: Host(
        id: '1',
        name: 'Hela Quintin',
        profileImageUrl: 'assets/images/profile_placeholder.png',
        isVerified: true,
      ),
      features: _getCarFeatures(),
      reviews: _getReviews(),
      totalReviews: 125,
    );
  }


  List<CarFeature> _getCarFeatures() {
    return [
      CarFeature(
        id: '1',
        label: 'Capacity',
        value: '${widget.car.seats} Seats',
        icon: Icons.event_seat,
      ),
      CarFeature(
        id: '2',
        label: 'Engine Out',
        value: '670 HP',
        icon: Icons.electric_bolt,
      ),
      CarFeature(
        id: '3',
        label: 'Max Speed',
        value: '250km/h',
        icon: Icons.speed,
      ),
      CarFeature(
        id: '4',
        label: 'Advance Autopilot',
        value: 'Autopilot',
        icon: Icons.directions_car,
      ),
      CarFeature(
        id: '5',
        label: 'Single Charge',
        value: '405 Miles',
        icon: Icons.flash_on,
      ),
      CarFeature(
        id: '6',
        label: 'Advance Auto Parking',
        value: 'Auto Parking',
        icon: Icons.local_parking,
      ),
    ];
  }

  List<Review> _getReviews() {
    return [
      Review(
        id: '1',
        userName: 'Mr. Jack',
        userImageUrl: 'assets/images/profile_placeholder.png',
        rating: 5.0,
        comment: 'The rental car was clean, reliable, and the service was quick and efficient.',
        date: DateTime.now().subtract(const Duration(days: 5)),
      ),
      Review(
        id: '2',
        userName: 'Robert',
        userImageUrl: 'assets/images/profile_placeholder.png',
        rating: 5.0,
        comment: 'Excellent car and amazing service. Highly recommend!',
        date: DateTime.now().subtract(const Duration(days: 10)),
      ),
      Review(
        id: '3',
        userName: 'Sarah',
        userImageUrl: 'assets/images/profile_placeholder.png',
        rating: 4.8,
        comment: 'Great experience overall. The car was in perfect condition.',
        date: DateTime.now().subtract(const Duration(days: 15)),
      ),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

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
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildImageCarousel(context, screenWidth, screenHeight),
                    _buildCarOverview(context),
                    const SizedBox(height: 24),
                    _buildHostSection(context),
                    const SizedBox(height: 24),
                    _buildFeaturesSection(context),
                    const SizedBox(height: 24),
                    _buildReviewsSection(context, screenWidth),
                    SizedBox(height: screenHeight * 0.12), // Space for bottom button
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBookNowButton(context, screenWidth),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, size: 20, color: Colors.black),
            ),
          ),
          const Text(
            'Car Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          Row(
            children: [
              _buildFavoriteButton(context),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {},
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.more_vert, size: 20, color: Colors.black),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImageCarousel(
    BuildContext context,
    double screenWidth,
    double screenHeight,
  ) {
    return Container(
      //margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
      height: screenHeight * 0.30,
      width: double.infinity,
      color: Colors.grey[100],
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _carDetail.imageUrls.length,
            itemBuilder: (context, index) {
              return Image.asset(
                _carDetail.imageUrls[index],
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(
                        Icons.directions_car,
                        size: 100,
                        color: Colors.grey,
                      ),
                    ),
                  );
                },
              );
            },
          ),
          // Pagination dots
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: SmoothPageIndicator(
                controller: _pageController,
                count: _carDetail.imageUrls.length,
                effect: const ExpandingDotsEffect(
                  activeDotColor: Colors.black87,
                  dotColor: Colors.grey,
                  dotHeight: 8,
                  dotWidth: 8,
                  spacing: 8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarOverview(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _carDetail.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _carDetail.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
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
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        _carDetail.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '(${_carDetail.totalReviews}+Reviews)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[300],
            ),
            child: ClipOval(
              child: Image.asset(
                _carDetail.host.profileImageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: const Icon(
                      Icons.person,
                      size: 32,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Text(
                  _carDetail.host.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                if (_carDetail.host.isVerified) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue[50],
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.phone, color: Colors.blue, size: 20),
          ),
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue[50],
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble_outline, color: Colors.blue, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Car features',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
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
              childAspectRatio: 1.1,
            ),
            itemCount: _carDetail.features.length,
            itemBuilder: (context, index) {
              final feature = _carDetail.features[index];
              return _buildFeatureCard(feature);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(CarFeature feature) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            feature.icon,
            size: 22,
            color: Colors.grey[700],
          ),
          const SizedBox(height: 8),
          Text(
            feature.label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          //const SizedBox(height: 4),
          Text(
            feature.value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection(BuildContext context, double screenWidth) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Review (${_carDetail.totalReviews})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'See All',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _carDetail.reviews.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.only(
                    right: index < _carDetail.reviews.length - 1 ? 16 : 0,
                  ),
                  child: _buildReviewCard(_carDetail.reviews[index]),
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
      width: 280,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[300],
                ),
                child: ClipOval(
                  child: Image.asset(
                    review.userImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[300],
                        child: const Icon(
                          Icons.person,
                          size: 24,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  review.userName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    review.rating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            review.comment,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteButton(BuildContext context) {
    final carAsync = ref.watch(carStreamProvider(widget.car.id));
    
    return carAsync.when(
      data: (car) {
        final isFavorite = car?.isFavorite ?? widget.car.isFavorite;
        final auth = ref.read(firebaseAuthProvider);
        final userId = auth.currentUser?.uid ?? '';

        return GestureDetector(
          onTap: () {
            if (userId.isNotEmpty) {
              ref.read(carControllerProvider).toggleFavorite(
                userId,
                widget.car.id,
                !isFavorite,
              );
            }
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              size: 20,
              color: isFavorite ? Colors.red : Colors.black,
            ),
          ),
        );
      },
      loading: () => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          shape: BoxShape.circle,
        ),
        child: Icon(
          widget.car.isFavorite ? Icons.favorite : Icons.favorite_border,
          size: 20,
          color: widget.car.isFavorite ? Colors.red : Colors.black,
        ),
      ),
      error: (_, __) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          shape: BoxShape.circle,
        ),
        child: Icon(
          widget.car.isFavorite ? Icons.favorite : Icons.favorite_border,
          size: 20,
          color: widget.car.isFavorite ? Colors.red : Colors.black,
        ),
      ),
    );
  }

  Widget _buildBookNowButton(BuildContext context, double screenWidth) {
    return Container(
      padding: EdgeInsets.only(
        left: screenWidth * 0.04,
        right: screenWidth * 0.04,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child:         ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BookingDetailsPage(car: widget.car),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2C2C2C),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text(
              'Book Now',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward, size: 20),
          ],
        ),
      ),
    );
  }
}

