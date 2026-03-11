import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with TickerProviderStateMixin {
  late final AnimationController _mainController;
  late final AnimationController _pulseController;
  late final AnimationController _shimmerController;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _taglineFade;
  late final Animation<double> _ringScale;
  late final Animation<double> _ringFade;
  late final Animation<double> _dotsFade;

  @override
  void initState() {
    super.initState();

    // Main entrance animation (1.8s)
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Pulsing glow loop
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Shimmer sweep loop
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    // Logo: scale up + fade in (0ms - 600ms)
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOutBack),
      ),
    );
    _logoFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
    );

    // Ring burst behind logo (200ms - 700ms)
    _ringScale = Tween<double>(begin: 0.5, end: 1.6).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.12, 0.45, curve: Curves.easeOut),
      ),
    );
    _ringFade = Tween<double>(begin: 0.4, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.12, 0.45, curve: Curves.easeIn),
      ),
    );

    // "Qent" text: slide up + fade in (400ms - 900ms)
    _textFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.25, 0.55, curve: Curves.easeOut),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.25, 0.55, curve: Curves.easeOutCubic),
    ));

    // Tagline fade in (600ms - 1100ms)
    _taglineFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.4, 0.65, curve: Curves.easeOut),
    );

    // Loading dots (900ms - 1200ms)
    _dotsFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.55, 0.75, curve: Curves.easeOut),
    );

    _mainController.forward();
    _pulseController.repeat(reverse: true);
    _shimmerController.repeat();
    _navigate();
  }

  Future<void> _navigate() async {
    final minDelay = Future.delayed(const Duration(milliseconds: 2500));
    await _waitForAuthRestore();
    await minDelay;

    if (!mounted) return;

    final authState = ref.read(authControllerProvider);
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

    if (!mounted) return;

    final String route;
    if (authState.user != null) {
      route = '/home';
    } else if (hasSeenOnboarding) {
      route = '/login';
    } else {
      route = '/onboarding';
    }

    Navigator.of(context).pushReplacementNamed(route);
  }

  Future<void> _waitForAuthRestore() async {
    await Future.delayed(const Duration(milliseconds: 100));
    for (int i = 0; i < 50; i++) {
      if (!mounted) return;
      final state = ref.read(authControllerProvider);
      if (!state.isLoading) return;
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Subtle radial gradient background
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.8 + (_pulseController.value * 0.15),
                    colors: [
                      const Color(0xFF1A1A2E).withValues(alpha: 0.6),
                      const Color(0xFF0A0A0A),
                    ],
                  ),
                ),
              );
            },
          ),

          // Floating particles
          ...List.generate(6, (i) => _buildFloatingDot(i)),

          // Center content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ring burst + Logo
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Expanding ring
                      AnimatedBuilder(
                        animation: _mainController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _ringScale.value,
                            child: Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: _ringFade.value),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      // Pulsing glow
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4A9EFF).withValues(
                                    alpha: 0.08 + (_pulseController.value * 0.06),
                                  ),
                                  blurRadius: 40 + (_pulseController.value * 15),
                                  spreadRadius: 5 + (_pulseController.value * 8),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      // Logo
                      FadeTransition(
                        opacity: _logoFade,
                        child: ScaleTransition(
                          scale: _logoScale,
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withValues(alpha: 0.1),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: Image.asset(
                                'assets/images/image_logo.png',
                                width: 48,
                                height: 48,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.directions_car_rounded,
                                  color: Color(0xFF0A0A0A),
                                  size: 36,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                //const SizedBox(height: 28),

                // "Qent" with shimmer
                SlideTransition(
                  position: _textSlide,
                  child: FadeTransition(
                    opacity: _textFade,
                    child: AnimatedBuilder(
                      animation: _shimmerController,
                      builder: (context, child) {
                        return ShaderMask(
                          shaderCallback: (bounds) {
                            return LinearGradient(
                              colors: const [
                                Colors.white,
                                Color(0xFFB0C4FF),
                                Colors.white,
                              ],
                              stops: [
                                (_shimmerController.value - 0.3).clamp(0.0, 1.0),
                                _shimmerController.value,
                                (_shimmerController.value + 0.3).clamp(0.0, 1.0),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds);
                          },
                          child: child!,
                        );
                      },
                      child: const Text(
                        'Qent',
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Tagline
                FadeTransition(
                  opacity: _taglineFade,
                  child: Text(
                    'Rent  .  Drive  .  Explore',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.4),
                      letterSpacing: 2,
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // Loading indicator
                /*FadeTransition(
                  opacity: _dotsFade,
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ),*/
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingDot(int index) {
    final random = math.Random(index * 42);
    final startX = random.nextDouble();
    final startY = random.nextDouble();
    final size = 2.0 + random.nextDouble() * 3;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final screenSize = MediaQuery.of(context).size;
        final drift = _pulseController.value * 8;
        final dx = startX * screenSize.width + math.sin(index * 1.2 + drift) * 12;
        final dy = startY * screenSize.height + math.cos(index * 0.8 + drift) * 12;
        final opacity = 0.1 + (_pulseController.value * 0.15);

        return Positioned(
          left: dx,
          top: dy,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: opacity),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
