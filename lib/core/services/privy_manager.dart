import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:privy_flutter/privy_flutter.dart';

/// V2 §6 — singleton wrapper around the Privy Flutter SDK.
///
/// Built once at app start (in `main()`); reused by `AuthController`
/// and any handler that needs to read the current Privy session or
/// call `getAccessToken` to revalidate against our backend.
///
/// Credentials come from `.env`:
///   PRIVY_APP_ID         — required (from console.privy.io)
///   PRIVY_APP_CLIENT_ID  — required
///   PRIVY_OAUTH_SCHEME   — must match Info.plist + AndroidManifest
class PrivyManager {
  PrivyManager._();
  static final PrivyManager _instance = PrivyManager._();
  factory PrivyManager() => _instance;

  Privy? _privy;
  bool _initFailed = false;
  String? _initErrorMessage;

  Privy get privy {
    final p = _privy;
    if (p == null) {
      throw StateError(
        _initErrorMessage ??
            'Privy not initialized. Did you call PrivyManager.initialize()?',
      );
    }
    return p;
  }

  bool get isReady => _privy != null;
  bool get initFailed => _initFailed;
  String? get initErrorMessage => _initErrorMessage;

  String get oAuthScheme => dotenv.env['PRIVY_OAUTH_SCHEME'] ?? 'qentauth';

  /// Build and await-ready. Safe to call once; subsequent calls no-op.
  Future<void> initialize() async {
    if (_privy != null || _initFailed) return;

    final appId = dotenv.env['PRIVY_APP_ID'] ?? '';
    final clientId = dotenv.env['PRIVY_APP_CLIENT_ID'] ?? '';

    if (appId.isEmpty || clientId.isEmpty) {
      _initFailed = true;
      _initErrorMessage =
          'PRIVY_APP_ID / PRIVY_APP_CLIENT_ID missing from .env';
      if (kDebugMode) {
        debugPrint('[Qent Privy] init skipped: $_initErrorMessage');
      }
      return;
    }

    try {
      final config = PrivyConfig(
        appId: appId,
        appClientId: clientId,
        logLevel: kDebugMode ? PrivyLogLevel.verbose : PrivyLogLevel.none,
      );
      final privy = Privy.init(config: config);
      // getAuthState awaits ready under the hood per the SDK docs.
      await privy.getAuthState();
      _privy = privy;
      if (kDebugMode) debugPrint('[Qent Privy] ready');
    } catch (e) {
      _initFailed = true;
      _initErrorMessage = e.toString();
      debugPrint('[Qent Privy] init failed: $e');
    }
  }

  /// Read the JWT to send to our `/api/auth/privy` endpoint. Returns
  /// null if not authenticated or the SDK isn't configured.
  Future<String?> currentAccessToken() async {
    final p = _privy;
    if (p == null) return null;
    final user = await p.getUser();
    if (user == null) return null;
    return tokenFromUser(user);
  }

  /// Pull the JWT out of a `PrivyUser` — the SDK's `Result` API is
  /// callback-based so we capture into a closure variable.
  Future<String?> tokenFromUser(PrivyUser user) async {
    String? token;
    final result = await user.getAccessToken();
    result.fold(
      onSuccess: (t) => token = t,
      onFailure: (e) {
        debugPrint('[Qent Privy] getAccessToken failed: ${e.message}');
      },
    );
    return token;
  }

  Future<void> logout() async {
    final p = _privy;
    if (p == null) return;
    try {
      await p.logout();
    } catch (e) {
      debugPrint('[Qent Privy] logout error: $e');
    }
  }
}

/// Top-level convenience getter mirroring the Privy starter sample.
final privyManager = PrivyManager();
