import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qent/core/services/email_verification_service.dart';
import 'package:qent/features/partner/presentation/controllers/partner_v2_controller.dart';
import 'package:qent/features/partner/presentation/pages/v2/editorial_owner_page.dart'
    show EditorialHeader, EditorialStepLabel, EditorialContinueButton;
import 'package:qent/features/partner/presentation/pages/v2/editorial_palette.dart';
import 'package:qent/features/partner/presentation/pages/v2/editorial_vehicle_page.dart';

/// Sub-step under Step 01 — confirm the contract email by entering the
/// 4-digit code Resend mails to the address. Header still reads
/// `01 / 06` so the partner's mental model of the flow stays at six
/// steps; this is conceptually a sub-step inside Step 01.
class EditorialEmailVerifyPage extends ConsumerStatefulWidget {
  final String email;
  const EditorialEmailVerifyPage({
    super.key,
    required this.email,
  });

  @override
  ConsumerState<EditorialEmailVerifyPage> createState() =>
      _EditorialEmailVerifyPageState();
}

class _EditorialEmailVerifyPageState
    extends ConsumerState<EditorialEmailVerifyPage> {
  // Backend generates 4-digit codes (see verification.rs::generate_code).
  static const _codeLength = 4;
  static const _resendSeconds = 60;

  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _emailService = EmailVerificationService();
  Timer? _ticker;
  int _remaining = _resendSeconds;
  bool _sending = false;
  bool _verifying = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      if (!mounted) return;
      setState(() {
        // Clear stale error as soon as the user starts retyping.
        if (_errorMessage != null) _errorMessage = null;
      });
    });
    // Fire the code on entry so the user doesn't have to wait for a
    // first manual tap. Server is idempotent — replays delete prior
    // codes for this email.
    _sendCode(initial: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _ticker?.cancel();
    setState(() => _remaining = _resendSeconds);
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_remaining <= 1) {
        t.cancel();
        setState(() => _remaining = 0);
      } else {
        setState(() => _remaining -= 1);
      }
    });
  }

  /// Ask the server to mail a fresh code. `initial=true` skips the
  /// "New code sent" confirmation snackbar (the page just opened, the
  /// host doesn't need to be told twice).
  Future<void> _sendCode({bool initial = false}) async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _errorMessage = null;
    });
    final ok = await _emailService.sendVerificationCode(widget.email);
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      _startCountdown();
      if (!initial) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New code sent')),
        );
      }
    } else {
      setState(() {
        _errorMessage = "Couldn't send the code. Try again in a moment.";
      });
    }
  }

  void _onResend() {
    if (_remaining > 0 || _sending) return;
    _sendCode();
  }

  String get _code => _ctrl.text;
  bool get _canContinue =>
      _code.length == _codeLength && !_verifying && !_sending;

  Future<void> _onContinue() async {
    if (!_canContinue) return;
    setState(() {
      _verifying = true;
      _errorMessage = null;
    });
    try {
      final ok =
          await _emailService.verifyCode(widget.email, _code);
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _errorMessage = 'Wrong code. Double-check and try again.';
          _ctrl.clear();
        });
        return;
      }
      // OTP confirmed — flip the partner-side flag so downstream steps
      // know the contract email is good.
      await ref
          .read(partnerV2ControllerProvider)
          .markEmailVerified(widget.email);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const EditorialVehiclePage()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EditorialPalette.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const EditorialHeader(stepIndex: 1, totalSteps: 5),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const EditorialStepLabel('STEP 01 · CONFIRM EMAIL'),
                    const SizedBox(height: 18),
                    _buildTitle(),
                    const SizedBox(height: 12),
                    _buildSubtitle(),
                    const SizedBox(height: 28),
                    _buildOtpBoxes(),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      _buildErrorLine(_errorMessage!),
                    ],
                    const SizedBox(height: 20),
                    _buildResend(),
                    const SizedBox(height: 22),
                    _buildHelpCard(),
                  ],
                ),
              ),
            ),
            EditorialContinueButton(
              label: _verifying ? 'Verifying…' : 'Verify & continue',
              onPressed: _onContinue,
              submitting: _verifying,
              enabled: _code.length == _codeLength,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      'Check your\ninbox.',
      style: GoogleFonts.roboto(
        color: EditorialPalette.textPrimary,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.1,
        letterSpacing: -0.6,
      ),
    );
  }

  Widget _buildSubtitle() {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.roboto(
          color: EditorialPalette.textSecondary,
          fontSize: 13,
          height: 1.5,
        ),
        children: [
          const TextSpan(text: 'We sent a 4-digit code to '),
          TextSpan(
            text: widget.email,
            style: GoogleFonts.roboto(
              color: EditorialPalette.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const TextSpan(text: '. It expires in 5 minutes.'),
        ],
      ),
    );
  }

  Widget _buildOtpBoxes() {
    return GestureDetector(
      onTap: () => _focus.requestFocus(),
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          // The visible row of 6 boxes — mirrors whatever's in `_ctrl`.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_codeLength, (i) {
              final char = i < _code.length ? _code[i] : '';
              final filled = char.isNotEmpty;
              final isCursor = i == _code.length && _focus.hasFocus;
              return _OtpBox(
                char: char,
                filled: filled,
                cursor: isCursor,
              );
            }),
          ),
          // Off-screen-but-focusable text field that owns the actual
          // text input. The boxes are read-only mirrors.
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(_codeLength),
                ],
                showCursor: false,
                style: const TextStyle(color: Colors.transparent),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResend() {
    final canResend = _remaining == 0;
    return Center(
      child: GestureDetector(
        onTap: canResend ? _onResend : null,
        child: RichText(
          text: TextSpan(
            style: GoogleFonts.roboto(
              color: EditorialPalette.textSecondary,
              fontSize: 13,
            ),
            children: [
              const TextSpan(text: "Didn't get it? "),
              TextSpan(
                text: canResend
                    ? 'Resend code'
                    : 'Resend in 0:${_remaining.toString().padLeft(2, '0')}',
                style: GoogleFonts.roboto(
                  color: canResend
                      ? EditorialPalette.textPrimary
                      : EditorialPalette.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  decoration: canResend
                      ? TextDecoration.underline
                      : TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorLine(String message) {
    return Row(
      children: [
        Icon(Icons.error_outline,
            size: 14, color: Colors.redAccent.shade400),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: GoogleFonts.roboto(
              color: Colors.redAccent.shade400,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHelpCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EditorialPalette.fieldFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: EditorialPalette.fieldBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.mail_outline,
                color: EditorialPalette.textPrimary, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Check your spam folder",
                  style: GoogleFonts.roboto(
                    color: EditorialPalette.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Codes from QENT sometimes land there on first sign-up.',
                  style: GoogleFonts.roboto(
                    color: EditorialPalette.textSecondary,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Single OTP cell. Empty cells show a thin dash placeholder; filled
/// cells show the digit in mono. The cursor cell gets a thicker
/// border so the user can see where the next keystroke will land.
class _OtpBox extends StatelessWidget {
  final String char;
  final bool filled;
  final bool cursor;
  const _OtpBox({
    required this.char,
    required this.filled,
    required this.cursor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cursor || filled
              ? EditorialPalette.textPrimary
              : EditorialPalette.fieldBorder,
          width: cursor || filled ? 1.6 : 1,
        ),
      ),
      child: filled
          ? Text(
              char,
              style: GoogleFonts.robotoMono(
                color: EditorialPalette.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w600,
              ),
            )
          : Container(
              width: 18,
              height: 2,
              decoration: BoxDecoration(
                color: EditorialPalette.fieldBorder,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
    );
  }
}
