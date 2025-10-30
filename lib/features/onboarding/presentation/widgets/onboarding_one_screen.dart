import 'package:flutter/material.dart';

class OnboardingOneScreen extends StatelessWidget {
  const OnboardingOneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/onboarding_one.png',
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.low,
          cacheWidth: (size.width * dpr).round(),
        ),

        // build header 
        
        // Blue tint overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
              Colors.black.withOpacity(0.915),
              Colors.black.withOpacity(0.83),
              Colors.black.withOpacity(0.3),
            ],
            stops: const [0.3, 0.6, 1.0],
           
          ),
        ),
        ),
        // Responsive, device-agnostic placement for the title
        Builder(
          builder: (context) {
            final size = MediaQuery.of(context).size;
            final safeTop = MediaQuery.of(context).padding.top;
            final double top = safeTop + size.height * 0.16; // 16% from top
            return Positioned(
              top: top,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Welcome to \nQent',
                        style: TextStyle(
                          color: Colors.white,
                          letterSpacing: -1.5,
                          height: 1.0,
                          fontSize: 45,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}