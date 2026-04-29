import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qent/core/services/email_verification_service.dart';
import 'package:qent/features/partner/presentation/pages/partner_payout_setup_page.dart';
import 'package:qent/core/theme/app_theme.dart';

class PartnerOtpPage extends StatefulWidget {
  final String email;

  const PartnerOtpPage({super.key, required this.email});

  @override
  State<PartnerOtpPage> createState() => _PartnerOtpPageState();
}

class _PartnerOtpPageState extends State<PartnerOtpPage> {
  final _controllers = List.generate(4, (_) => TextEditingController());
  final _focusNodes = List.generate(4, (_) => FocusNode());
  final _verificationService = EmailVerificationService();
  bool _isVerifying = false;
  bool _isResending = false;
  int _remainingSeconds = 59;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _remainingSeconds = 59;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otpCode => _controllers.map((c) => c.text).join();

  Future<void> _handleVerify() async {
    final code = _otpCode;
    if (code.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the full 4-digit code')),
      );
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final verified = await _verificationService.verifyCode(widget.email, code);

      if (!mounted) return;

      if (verified) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PartnerPayoutSetupPage()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid or expired code. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification failed: ${e.toString().replaceFirst("Exception: ", "")}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _handleResend() async {
    if (_remainingSeconds > 0) return;

    setState(() => _isResending = true);
    try {
      await _verificationService.sendVerificationCode(widget.email);
      if (!mounted) return;
      _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification code resent!')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to resend code'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgPrimary,
      appBar: AppBar(
        backgroundColor: context.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: context.borderColor),
            ),
            child: Icon(Icons.arrow_back, color: context.textPrimary, size: 18),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'OTP Verification',
          style: GoogleFonts.inter(color: context.textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.more_horiz, color: context.textPrimary),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              Text(
                'Enter your Verification Code',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: context.textPrimary),
              ),
              const SizedBox(height: 12),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600], height: 1.5),
                  children: [
                    const TextSpan(text: 'Please enter the OTP (One-Time Password) sent to your registered '),
                    TextSpan(
                      text: 'Email address',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const TextSpan(text: ' to complete your verification'),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) => _otpBox(i)),
              ),
              const SizedBox(height: 20),
              Text(
                'Remaining Time :00:${_remainingSeconds.toString().padLeft(2, '0')}s',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C2C2C),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                  onPressed: _isVerifying ? null : _handleVerify,
                  child: _isVerifying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'Verify Now',
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Didn't receive the OTP?",
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: _remainingSeconds == 0 ? _handleResend : null,
                child: Text(
                  _isResending ? 'Sending...' : 'Resend.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _remainingSeconds == 0 ? context.textPrimary : context.textTertiary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _otpBox(int index) {
    return Container(
      width: 56,
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: context.inputBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _focusNodes[index].hasFocus ? context.textPrimary : context.inputBorder,
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        // iOS SMS autofill drops the whole code into the first field at once,
        // so the first cell can't have maxLength=1 — we split the value
        // ourselves below. Subsequent cells keep maxLength=1.
        maxLength: index == 0 ? null : 1,
        keyboardType: TextInputType.number,
        // Tells iOS this is an SMS one-time code; needed for autofill suggestion
        autofillHints: index == 0 ? const [AutofillHints.oneTimeCode] : null,
        style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
        ),
        onChanged: (v) {
          // Autofill case: iOS pastes the full 4-digit code into the first
          // field. Split it across all 4 cells.
          if (index == 0 && v.length > 1) {
            final digits = v.replaceAll(RegExp(r'\D'), '');
            for (var i = 0; i < _controllers.length; i++) {
              _controllers[i].text = i < digits.length ? digits[i] : '';
            }
            // Move focus to the last filled cell (or last cell if full)
            final last = digits.length.clamp(1, _controllers.length) - 1;
            _focusNodes[last].requestFocus();
            setState(() {});
            return;
          }
          if (v.length == 1 && index < 3) {
            _focusNodes[index + 1].requestFocus();
          } else if (v.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
          setState(() {});
        },
      ),
    );
  }
}
