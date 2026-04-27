import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';

class IosVersion {
  static int? _cachedMajor;

  /// Returns true if running on iOS 26.0 or later. False on Android, web, or older iOS.
  /// Result is cached after first call.
  static Future<bool> isIOS26OrLater() async {
    if (!Platform.isIOS) return false;
    if (_cachedMajor != null) return _cachedMajor! >= 26;

    try {
      final info = await DeviceInfoPlugin().iosInfo;
      final parts = info.systemVersion.split('.');
      final major = int.tryParse(parts.first) ?? 0;
      _cachedMajor = major;
      return major >= 26;
    } catch (_) {
      _cachedMajor = 0;
      return false;
    }
  }
}
