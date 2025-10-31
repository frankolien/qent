import 'package:flutter/material.dart';
import 'package:qent/features/onboarding/presentation/widgets/onboarding_one_screen.dart';
import 'package:qent/features/onboarding/presentation/widgets/onboarding_two_screen.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 2;
  @override
  Widget build(BuildContext context) {
    final mediaPadding = MediaQuery.of(context).padding;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Fullscreen pages
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,
              physics: const ClampingScrollPhysics(),
              itemCount: _totalPages,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                switch (index) {
                  case 0:
                    return const OnboardingOneScreen();
                  case 1:
                    return const OnboardingTwoScreen();
                  default:
                    return const SizedBox.shrink();
                }
              },
            ),
          ),
          // Header overlay
          Positioned(
            top: mediaPadding.top + 8,
            left: 16,
            right: 16,
            child: _buildHeader(),
          ),
          // Bottom controls overlay
          Positioned(
            left: 0,
            right: 0,
            bottom: mediaPadding.bottom + 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPageIndicator(),
                _buildNavigationButtons(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Image.asset('assets/images/image_logo.png', width: 60, height: 60, fit: BoxFit.cover),
      ],
    );
  }
  Widget _buildPageIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Center(
        child: SmoothPageIndicator(
          controller: _pageController,
          count: _totalPages,
          effect: const WormEffect(
            dotHeight: 6,
            dotWidth: 6,
            activeDotColor: Colors.white,
            dotColor: Colors.white38,
          ),
        ),
      ),
    );
  }
  Widget _buildNavigationButtons() {
    final bool isLastPage = _currentPage == _totalPages - 1;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 54,
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black.withOpacity(0.8),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          onPressed: () {
            if (isLastPage) {
              // Placeholder: navigate to next route when available
              Navigator.pushNamed(context, '/login');
            } else {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          },
          child: Text(isLastPage ? 'Get Started' : 'Next'),
        ),
      ),
    );
  }
}