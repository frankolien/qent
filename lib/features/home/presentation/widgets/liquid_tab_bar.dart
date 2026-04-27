import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// iOS 26 Liquid Glass tab bar, embedded as a SwiftUI PlatformView.
/// Mirrors the public API of CustomBottomNav so swapping is transparent.
class LiquidTabBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final String? profilePhotoUrl;

  const LiquidTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.profilePhotoUrl,
  });

  @override
  State<LiquidTabBar> createState() => _LiquidTabBarState();
}

class _LiquidTabBarState extends State<LiquidTabBar> {
  static const _viewType = 'qent.online/liquid_tab_bar';
  MethodChannel? _channel;

  @override
  void didUpdateWidget(LiquidTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _channel?.invokeMethod('setSelectedIndex', widget.currentIndex);
    }
    if (oldWidget.profilePhotoUrl != widget.profilePhotoUrl) {
      _channel?.invokeMethod('setProfilePhotoUrl', widget.profilePhotoUrl);
    }
  }

  void _onPlatformViewCreated(int viewId) {
    _channel = MethodChannel('qent.online/liquid_tab/$viewId');
    _channel!.setMethodCallHandler((call) async {
      if (call.method == 'tabSelected' && call.arguments is int) {
        widget.onTap(call.arguments as int);
      }
      return null;
    });
    // Push initial state so SwiftUI matches Flutter on first paint.
    _channel!.invokeMethod('setSelectedIndex', widget.currentIndex);
    if (widget.profilePhotoUrl != null) {
      _channel!.invokeMethod('setProfilePhotoUrl', widget.profilePhotoUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: UiKitView(
        viewType: _viewType,
        onPlatformViewCreated: _onPlatformViewCreated,
        creationParamsCodec: const StandardMessageCodec(),
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
      ),
    );
  }
}
