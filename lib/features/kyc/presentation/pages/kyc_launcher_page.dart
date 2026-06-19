import 'package:flutter/material.dart';
import 'package:flutter_idensic_mobile_sdk_plugin/flutter_idensic_mobile_sdk_plugin.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/core/theme/app_theme.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart';
import 'package:qent/features/kyc/data/datasources/kyc_datasource.dart';
import 'package:qent/features/kyc/domain/models/kyc_access_token.dart';
import 'package:qent/features/kyc/presentation/providers/kyc_providers.dart';

/// V2 §6.7 — KYC launcher. Fetches a Sumsub access token from the
/// backend, then hands off to the Sumsub mobile SDK. When the SDK
/// returns, we refresh the user's profile — by then the server has
/// already flipped `kyc_tier` via the Sumsub webhook handler.
class KycLauncherPage extends ConsumerStatefulWidget {
  final VoidCallback? onTierUpgraded;

  const KycLauncherPage({super.key, this.onTierUpgraded});

  @override
  ConsumerState<KycLauncherPage> createState() => _KycLauncherPageState();
}

class _KycLauncherPageState extends ConsumerState<KycLauncherPage> {
  bool _loading = false;
  KycAccessToken? _token;
  String? _error;
  SNSMobileSDKResult? _lastSdkResult;

  /// One-shot — mints a fresh token from the backend, then opens
  /// the Sumsub mobile SDK. On any failure to even fetch the token
  /// we just surface the message; the user can tap again.
  Future<void> _startVerification() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await ref.read(kycDataSourceProvider).fetchAccessToken();
      if (!mounted) return;
      setState(() => _token = token);
      await _launchSumsub(token);
    } on KycException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.isCountryMissing
            ? 'Pick your country first.'
            : e.isProviderNotConfigured
                ? 'Identity verification is being set up. Try again shortly.'
                : e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Opens the inline Sumsub flow. `onTokenExpiration` is a callback
  /// the SDK invokes if the user takes longer than the token TTL —
  /// we just mint a new one from the backend and hand it back.
  Future<void> _launchSumsub(KycAccessToken token) async {
    Future<String> onTokenExpiration() async {
      try {
        final fresh = await ref.read(kycDataSourceProvider).fetchAccessToken();
        return fresh.token;
      } catch (_) {
        return token.token; // last-resort; SDK will surface the failure
      }
    }

    final sdk = SNSMobileSDK.init(token.token, onTokenExpiration)
        .withDebug(true)
        .build();

    final result = await sdk.launch();
    if (!mounted) return;
    setState(() => _lastSdkResult = result);
    // The Sumsub webhook + our backend handler are the source of
    // truth for kyc_tier; we just re-read /profile to pick it up.
    await ref.read(authControllerProvider.notifier).refreshProfile();
    if (!mounted) return;
    widget.onTierUpgraded?.call();
  }

  Future<void> _refreshTier() async {
    await ref.read(authControllerProvider.notifier).refreshProfile();
    if (!mounted) return;
    widget.onTierUpgraded?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: QentColors.background,
      appBar: AppBar(
        backgroundColor: QentColors.background,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: const Text(
          'Verify identity',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Bullets(),
              const Spacer(),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: QentColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: QentColors.error),
                  ),
                ),
              if (_token != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: QentColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Flow: ${_token!.levelName}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Token expires ${_token!.expiresAt.toLocal()}',
                        style: const TextStyle(
                          color: QentColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Sumsub mobile SDK integration is pending — once '
                        'wired, this page launches the inline verification '
                        'flow directly. Tap Refresh below after completing '
                        'verification to pick up the new tier.',
                        style: TextStyle(
                          color: QentColors.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _loading
                      ? null
                      : (_lastSdkResult == null
                          ? _startVerification
                          : _refreshTier),
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _lastSdkResult == null
                              ? 'Start verification'
                              : 'Refresh status',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bullets extends StatelessWidget {
  const _Bullets();

  @override
  Widget build(BuildContext context) {
    final items = const [
      ('Government ID', 'Driver\'s licence, passport, or national ID.'),
      ('Selfie + liveness', 'Quick face check — no makeup or filters.'),
      ('60-second flow', 'Most users finish on the first try.'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Renters need to verify once.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We use this to protect hosts and unlock booking.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28),
        ...items.map((entry) {
          final (title, sub) = entry;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: const BoxDecoration(
                    color: QentColors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: QentColors.accent,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        style: const TextStyle(
                          color: QentColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
