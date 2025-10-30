import 'package:flutter/material.dart';

class OnboardingTwoScreen extends StatefulWidget {
  const OnboardingTwoScreen({super.key});

  @override
  State<OnboardingTwoScreen> createState() => _OnboardingTwoScreenState();
}

class _OnboardingTwoScreenState extends State<OnboardingTwoScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final size = MediaQuery.of(context).size;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/onboarding_two.png',
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.low,
            cacheWidth: (size.width * dpr).round(),
          ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.95),
                Colors.black.withOpacity(0.8),
                Colors.black.withOpacity(0.30),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
        // Responsive heading block (top area)
        Builder(
          builder: (context) {
            final size = MediaQuery.of(context).size;
            final safeTop = MediaQuery.of(context).padding.top;
            final double top = safeTop + size.height * 0.18; // 18% from top
            return Positioned(
              top: top,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'Lets Start',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'A New Experience',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'With Car rental.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        // Responsive description block (bottom area)
        Builder(
          builder: (context) {
            final size = MediaQuery.of(context).size;
            final safeBottom = MediaQuery.of(context).padding.bottom;
            final double bottom = safeBottom + size.height * 0.18; 
            return Positioned(
              left: 0,
              right: 0,
              bottom: bottom,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: const Text(
                  "Discover your next adventure with Qent, we're here to\nprovide you with a seamless car rental experience.\nLet's get started on your journey.",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    ),
    );
  }
}