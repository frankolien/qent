import 'package:flutter/material.dart';
import 'package:qent/features/home/domain/models/car.dart';
import 'package:qent/features/home/presentation/widgets/brand_item.dart';
import 'package:qent/features/home/presentation/widgets/car_card.dart';
import 'package:qent/features/home/presentation/widgets/nearby_car_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Car> _bestCars = [
    Car(
      id: '1',
      name: 'Ferrari-FF',
      brand: 'Ferrari',
      imageUrl: 'assets/images/ferrari_ff.png',
      rating: 5.0,
      location: 'Washington DC',
      seats: 4,
      pricePerDay: 200,
    ),
    Car(
      id: '2',
      name: 'Tesla Model S',
      brand: 'Tesla',
      imageUrl: 'assets/images/tesla_model_s.png',
      rating: 5.0,
      location: 'Chicago, USA',
      seats: 5,
      pricePerDay: 100,
    ),
  ];

  final List<Car> _nearbyCars = [
    Car(
      id: '3',
      name: 'BMW M4',
      brand: 'BMW',
      imageUrl: 'assets/images/bmw_m4.png',
      rating: 4.8,
      location: 'Lagos, Nigeria',
      seats: 4,
      pricePerDay: 150,
    ),
  ];

  final List<String> _brands = [
    'Tesla',
    'Lamborghini',
    'BMW',
    'Ferrari',
  ];

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      backgroundColor: Color(0xFFF8F8F8),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            SizedBox(height: screenHeight * 0.025),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSearchBar(context),
                    SizedBox(height: screenHeight * 0.025),
                    _buildBrandsSection(context),
                    SizedBox(height: screenHeight * 0.050),
                    Container(
                      
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(topLeft: Radius.circular(40), topRight: Radius.circular(40)),
                      ),
                      child: Column(
                        children: [
                          _buildBestCarsSection(context),
                          SizedBox(height: screenHeight * 0.025),
                          _buildNearbySection(context),
                        ],
                      )
                      ),
                    /*SizedBox(height: screenHeight * 0.025),
                    _buildNearbySection(context),*/
                    SizedBox(height: screenHeight * 0.1), // Space for bottom nav
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Padding(
      padding: EdgeInsets.fromLTRB(
        screenWidth * 0.04,
        MediaQuery.of(context).size.height * 0.02,
        screenWidth * 0.04,
        MediaQuery.of(context).size.height * 0.015,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            child: Image.asset(
              'assets/images/image_logo.png',
              width: 30,
              height: 30,
            ),
          ),
              SizedBox(width: screenWidth * 0.025),
              const Text(
            'Qent',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
            ],
          ),
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded, size: 26),
                    onPressed: () {},
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          '2',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(width: screenWidth * 0.025),
              Container(
                width: 40,
                height: 40,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                child: ClipOval(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {},
                      child: const Icon(Icons.person, size: 22, color: Colors.black),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
      child: Row(
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 50),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Icon(Icons.search, color: Colors.grey[600], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search your dream car.....',
                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                        fillColor: Colors.white,
                        filled: true,
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: screenWidth * 0.03),
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                //borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.tune, size: 20, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandsSection(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
          child: const Text(
            'Brands',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 70,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
            itemCount: _brands.length,
            itemBuilder: (context, index) {
              return BrandItem(brand: _brands[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBestCarsSection(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardHeight = MediaQuery.of(context).size.height * 0.28;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children:  [
                  Text(
                    'Best Cars',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 4),
                    TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                
                  'View All',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
                  
                ],
              ),
            
              Text(  
                    'Available',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: cardHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
            itemCount: _bestCars.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index < _bestCars.length - 1 ? screenWidth * 0.04 : 0,
                ),
                child: CarCard(
                  car: _bestCars[index],
                  onFavoriteTap: () {
                    setState(() {
                      _bestCars[index] = _bestCars[index].copyWith(
                        isFavorite: !_bestCars[index].isFavorite,
                      );
                    });
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNearbySection(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Nearby',
                style: TextStyle(
                  fontSize: 20,
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
                  'View All',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_nearbyCars.isNotEmpty)
          NearbyCarCard(
            car: _nearbyCars[0],
            onFavoriteTap: () {
              setState(() {
                _nearbyCars[0] = _nearbyCars[0].copyWith(
                  isFavorite: !_nearbyCars[0].isFavorite,
                );
              });
            },
          ),
      ],
    );
  }
}