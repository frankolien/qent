import 'dart:math';
import 'package:flutter/material.dart';

/// Custom pull-to-refresh that shows an animated car instead of Material spinner.
/// Wraps any scrollable child widget.
class CarPullToRefresh extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  const CarPullToRefresh({
    super.key,
    required this.child,
    required this.onRefresh,
  });

  @override
  State<CarPullToRefresh> createState() => _CarPullToRefreshState();
}

class _CarPullToRefreshState extends State<CarPullToRefresh>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0;
  bool _isRefreshing = false;
  bool _isDragging = false;
  late final AnimationController _resetController;
  late Animation<double> _resetAnimation;

  static const double _triggerDistance = 100;
  static const double _maxDrag = 140;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _handleScrollUpdate(ScrollUpdateNotification notification) {
    if (_isRefreshing) return;
    final pixels = notification.metrics.pixels;

    // With BouncingScrollPhysics, pulling past top gives negative pixels
    if (pixels < 0) {
      _isDragging = true;
      setState(() {
        _dragOffset = (-pixels).clamp(0, _maxDrag).toDouble();
      });
    } else if (_isDragging && pixels >= 0) {
      // User scrolled back past zero — cancel the pull
      setState(() => _dragOffset = 0);
      _isDragging = false;
    }
  }

  void _handleScrollEnd() {
    if (_isRefreshing || !_isDragging) return;
    _isDragging = false;
    if (_dragOffset >= _triggerDistance) {
      _startRefresh();
    } else {
      _animateReset();
    }
  }

  Future<void> _startRefresh() async {
    setState(() => _isRefreshing = true);
    setState(() => _dragOffset = 70);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
        _animateReset();
      }
    }
  }

  void _animateReset() {
    _resetAnimation = Tween<double>(begin: _dragOffset, end: 0).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOutCubic),
    );
    _resetController.forward(from: 0).then((_) {
      if (mounted) setState(() => _dragOffset = 0);
    });
    _resetAnimation.addListener(() {
      if (mounted) setState(() => _dragOffset = _resetAnimation.value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_dragOffset / _triggerDistance).clamp(0.0, 1.0);

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          _handleScrollUpdate(notification);
        } else if (notification is ScrollEndNotification) {
          _handleScrollEnd();
        }
        return false;
      },
      child: Stack(
        children: [
          // Behind: car indicator (visible through transparent bounce gap)
          if (_dragOffset > 0)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: _isRefreshing ? _dragOffset : _dragOffset,
              child: Container(
                color: Colors.transparent,
                alignment: Alignment.center,
                child: _isRefreshing
                    ? const _RefreshingCarAnimation(size: 32)
                    : _PullingCarAnimation(progress: progress, size: 32),
              ),
            ),
          // On top: scrollable content
          // During pull: BouncingScrollPhysics creates visual gap (no padding needed)
          // During refresh: bounce springs back, so manually pad content down
          _isRefreshing
              ? Padding(
                  padding: EdgeInsets.only(top: _dragOffset),
                  child: widget.child,
                )
              : widget.child,
        ],
      ),
    );
  }
}

/// Shows car driving in from left as user pulls down
class _PullingCarAnimation extends StatelessWidget {
  final double progress;
  final double size;

  const _PullingCarAnimation({required this.progress, required this.size});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Car slides in from left based on pull progress
        Transform.translate(
          offset: Offset(-40 + (progress * 40), 0),
          child: Opacity(
            opacity: progress,
            child: Transform.rotate(
              angle: -0.05 + (progress * 0.05),
              child: Icon(
                Icons.directions_car_rounded,
                size: size,
                color: const Color(0xFF1A1A1A),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Road dots appear as car drives
        ...List.generate(3, (i) {
          final dotProgress = (progress - (i * 0.2)).clamp(0.0, 1.0);
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 6 * dotProgress,
            height: 2.5,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A).withValues(alpha: dotProgress * 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ],
    );
  }
}

/// Animated car bouncing while data loads
class _RefreshingCarAnimation extends StatefulWidget {
  final double size;
  const _RefreshingCarAnimation({required this.size});

  @override
  State<_RefreshingCarAnimation> createState() => _RefreshingCarAnimationState();
}

class _RefreshingCarAnimationState extends State<_RefreshingCarAnimation>
    with TickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final AnimationController _dotsController;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_bounceController, _dotsController]),
      builder: (context, child) {
        final bounce = Tween<double>(begin: 0, end: -4)
            .animate(CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut))
            .value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.translate(
              offset: Offset(0, bounce),
              child: Icon(
                Icons.directions_car_rounded,
                size: widget.size,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(width: 6),
            ...List.generate(4, (i) {
              final p = (_dotsController.value * 4 - i) % 4;
              final opacity = (1.0 - (p / 4)).clamp(0.2, 0.8);
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                width: 5 + p,
                height: 2.5,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A).withValues(alpha: opacity),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

/// Animated car loading indicator with bouncing road animation
class AnimatedCarLoading extends StatefulWidget {
  final double size;
  final Color color;

  const AnimatedCarLoading({
    super.key,
    this.size = 48,
    this.color = const Color(0xFF1A1A1A),
  });

  @override
  State<AnimatedCarLoading> createState() => _AnimatedCarLoadingState();
}

class _AnimatedCarLoadingState extends State<AnimatedCarLoading>
    with TickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final AnimationController _dotsController;
  late final Animation<double> _bounceAnimation;
  late final Animation<double> _tiltAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _bounceAnimation = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );

    _tiltAnimation = Tween<double>(begin: -0.03, end: 0.03).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 2.5,
      height: widget.size * 1.8,
      child: AnimatedBuilder(
        animation: Listenable.merge([_bounceController, _dotsController]),
        builder: (context, child) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.translate(
                offset: Offset(0, _bounceAnimation.value),
                child: Transform.rotate(
                  angle: _tiltAnimation.value,
                  child: Icon(
                    Icons.directions_car_rounded,
                    size: widget.size,
                    color: widget.color,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 4,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final progress = (_dotsController.value * 5 - i) % 5;
                    final opacity = (1.0 - (progress / 5)).clamp(0.15, 1.0);
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 8 + (progress * 2).clamp(0, 6),
                      height: 3,
                      decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: opacity),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Pulsing dot loader (3 dots that pulse in sequence)
class PulsingDotsLoader extends StatefulWidget {
  final Color color;
  final double dotSize;

  const PulsingDotsLoader({
    super.key,
    this.color = const Color(0xFF1A1A1A),
    this.dotSize = 8,
  });

  @override
  State<PulsingDotsLoader> createState() => _PulsingDotsLoaderState();
}

class _PulsingDotsLoaderState extends State<PulsingDotsLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final t = ((_controller.value - delay) % 1.0).clamp(0.0, 1.0);
            final scale = 0.5 + 0.5 * sin(t * pi);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: widget.dotSize,
              height: widget.dotSize,
              child: Transform.scale(
                scale: scale,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.4 + 0.6 * scale),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Staggered fade + slide-up animation for list items
class StaggeredFadeIn extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration delay;
  final Duration duration;

  const StaggeredFadeIn({
    super.key,
    required this.child,
    this.index = 0,
    this.delay = const Duration(milliseconds: 80),
    this.duration = const Duration(milliseconds: 400),
  });

  @override
  State<StaggeredFadeIn> createState() => _StaggeredFadeInState();
}

class _StaggeredFadeInState extends State<StaggeredFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    Future.delayed(widget.delay * widget.index, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}
