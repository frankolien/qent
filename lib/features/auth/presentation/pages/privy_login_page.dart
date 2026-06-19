import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:privy_flutter/privy_flutter.dart' hide AuthState;
import 'package:qent/core/services/privy_manager.dart';
import 'package:qent/core/theme/app_theme.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart';

/// V2 §6.4 — Privy-backed sign-in. Same visual structure as the V1
/// LoginPage (logo + wordmark, two-line headline, theme-aware
/// surfaces, real Google SVG, footer link) — but the underlying
/// flow is Privy: Google/Apple OAuth and email magic-link OTP. No
/// password field anymore (Privy = passwordless).
class PrivyLoginPage extends ConsumerStatefulWidget {
  const PrivyLoginPage({super.key});

  @override
  ConsumerState<PrivyLoginPage> createState() => _PrivyLoginPageState();
}

class _PrivyLoginPageState extends ConsumerState<PrivyLoginPage> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  bool _codeSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final loading = state.isLoading;
    final privyDown = privyManager.initFailed;

    ref.listen<String?>(
      authControllerProvider.select((s) => s.errorMessage),
      (prev, next) {
        if (next != null && next.isNotEmpty && next != prev) {
          _showToast(next);
          ref.read(authControllerProvider.notifier).clearError();
        }
      },
    );

    return Scaffold(
      backgroundColor: context.bgPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              _buildAppBar(context),
              const SizedBox(height: 36),
              _buildTitle(context),
              const SizedBox(height: 28),
              if (privyDown)
                _ConfigMissingBanner(
                  message: privyManager.initErrorMessage ?? '',
                )
              else if (!_codeSent) ...[
                _buildEmailInput(context, loading),
                const SizedBox(height: 14),
                _buildPrimaryButton(
                  context,
                  label: 'Send code',
                  loading: loading,
                  onPressed: loading ? null : _sendCode,
                ),
                const SizedBox(height: 20),
                _buildSeparator(context),
                const SizedBox(height: 20),
                _buildSocialButtons(context, loading),
              ] else ...[
                _buildCodeInstructions(context),
                const SizedBox(height: 14),
                _buildCodeInput(context, loading),
                const SizedBox(height: 14),
                _buildPrimaryButton(
                  context,
                  label: 'Verify & continue',
                  loading: loading,
                  onPressed: loading ? null : _confirmCode,
                ),
                const SizedBox(height: 10),
                _buildChangeEmailButton(context, loading),
              ],
              const SizedBox(height: 28),
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  // ----- Header --------------------------------------------------------

  Widget _buildAppBar(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/image_logo.png',
              width: 26,
              height: 26,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Qent',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _codeSent ? 'Check your email' : 'Welcome',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
            height: 1.15,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _codeSent
              ? "We just sent you a code."
              : 'Rent any car, anywhere.',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
            height: 1.15,
            letterSpacing: -0.8,
          ),
        ),
      ],
    );
  }

  // ----- Social --------------------------------------------------------

  Widget _buildSocialButtons(BuildContext context, bool loading) {
    final showApple = !kIsWeb && Platform.isIOS;
    final controller = ref.read(authControllerProvider.notifier);

    return Column(
      children: [
        if (showApple) ...[
          _buildSocialButton(
            context: context,
            icon: Icons.apple,
            iconSize: 22,
            label: 'Continue with Apple',
            onPressed: loading
                ? null
                : () =>
                    controller.signInWithPrivyOAuth(OAuthProvider.apple),
          ),
          const SizedBox(height: 12),
        ],
        _buildSocialButton(
          context: context,
          leading: SvgPicture.asset(
            'assets/images/google_logo.svg',
            width: 20,
            height: 20,
          ),
          label: 'Continue with Google',
          onPressed: loading
              ? null
              : () => controller.signInWithPrivyOAuth(OAuthProvider.google),
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required BuildContext context,
    IconData? icon,
    Widget? leading,
    required String label,
    required VoidCallback? onPressed,
    double iconSize = 22,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: context.bgSecondary,
          foregroundColor: context.textPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            leading ?? Icon(icon, size: iconSize),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeparator(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: context.borderColor, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'Or',
            style: TextStyle(color: context.textSecondary, fontSize: 13),
          ),
        ),
        Expanded(child: Divider(color: context.borderColor, height: 1)),
      ],
    );
  }

  // ----- Email + code --------------------------------------------------

  Widget _buildEmailInput(BuildContext context, bool loading) {
    return TextField(
      controller: _emailController,
      enabled: !loading,
      keyboardType: TextInputType.emailAddress,
      autocorrect: false,
      style: TextStyle(fontSize: 15, color: context.textPrimary),
      decoration: InputDecoration(
        hintText: 'you@example.com',
        hintStyle: TextStyle(color: context.textTertiary, fontSize: 15),
        filled: true,
        fillColor: context.inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: context.isDark
                ? context.accent.withValues(alpha: 0.6)
                : Colors.black26,
            width: 1,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      ),
    );
  }

  Widget _buildCodeInstructions(BuildContext context) {
    return Text(
      _emailController.text.trim(),
      style: TextStyle(color: context.textSecondary, fontSize: 14),
    );
  }

  Widget _buildCodeInput(BuildContext context, bool loading) {
    return TextField(
      controller: _codeController,
      enabled: !loading,
      keyboardType: TextInputType.number,
      autocorrect: false,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: context.textPrimary,
        fontSize: 22,
        letterSpacing: 8,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: '••••••',
        hintStyle: TextStyle(
          color: context.textTertiary,
          letterSpacing: 8,
          fontSize: 22,
        ),
        filled: true,
        fillColor: context.inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: context.isDark
                ? context.accent.withValues(alpha: 0.6)
                : Colors.black26,
            width: 1,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      ),
    );
  }

  Widget _buildChangeEmailButton(BuildContext context, bool loading) {
    return Center(
      child: TextButton(
        onPressed: loading
            ? null
            : () => setState(() {
                  _codeSent = false;
                  _codeController.clear();
                }),
        child: Text(
          'Use a different email',
          style: TextStyle(
            color: context.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ----- Primary button ------------------------------------------------

  Widget _buildPrimaryButton(
    BuildContext context, {
    required String label,
    required bool loading,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              context.isDark ? context.accent : const Color(0xFF1A1A1A),
          disabledBackgroundColor: context.isDark
              ? context.accent.withValues(alpha: 0.6)
              : const Color(0xFF1A1A1A).withValues(alpha: 0.6),
          foregroundColor: context.isDark ? Colors.black : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  // ----- Footer --------------------------------------------------------

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Center(
        child: Text(
          'By continuing you agree to our terms and privacy policy.',
          style: TextStyle(color: context.textTertiary, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // ----- Actions -------------------------------------------------------

  Future<void> _sendCode() async {
    // Lowercase — Privy keys OTPs against the normalized email, so
    // sending mixed case at send-time and confirm-time can be read
    // as different recipients.
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      _showToast('Enter a valid email');
      return;
    }
    _emailController.text = email; // reflect normalization back to the user
    final ok =
        await ref.read(authControllerProvider.notifier).sendPrivyEmailCode(email);
    if (ok && mounted) {
      setState(() => _codeSent = true);
    }
  }

  Future<void> _confirmCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _showToast('Enter the code');
      return;
    }
    await ref.read(authControllerProvider.notifier).confirmPrivyEmailCode(
          email: _emailController.text.trim().toLowerCase(),
          code: code,
        );
    // After Privy rejects a code it's burnt server-side. Clear the
    // field so the next tap doesn't resend the same dead string —
    // the user has to read the freshest email and retype.
    if (mounted && ref.read(authControllerProvider).errorMessage != null) {
      _codeController.clear();
    }
  }

  void _showToast(String message) {
    if (!mounted) return;
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastOverlay(
        message: message,
        onDismiss: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }
}

// ---------------------------------------------------------------------
// Toast overlay — same animation/styling as the V1 LoginPage toast so
// auth errors feel identical across the two entry points.
// ---------------------------------------------------------------------

class _ToastOverlay extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ToastOverlay({required this.message, required this.onDismiss});

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
    Future.delayed(const Duration(seconds: 3), _dismiss);
  }

  void _dismiss() {
    if (!mounted) return;
    _controller.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 20,
      right: 20,
      child: SlideTransition(
        position: _slideAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFFF6B6B),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _dismiss,
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white54,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------

class _ConfigMissingBanner extends StatelessWidget {
  final String message;
  const _ConfigMissingBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber, color: Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              Text(
                'Sign-in not configured',
                style: TextStyle(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Add PRIVY_APP_ID and PRIVY_APP_CLIENT_ID to mobile/.env, '
            'then restart the app.',
            style: TextStyle(color: context.textSecondary, fontSize: 13),
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: context.textTertiary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
