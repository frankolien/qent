import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:qent/core/services/api_client.dart';
import 'package:qent/features/booking/domain/models/booking_confirmation.dart';
import 'package:qent/features/booking/domain/models/payment_method.dart';
import 'package:qent/features/booking/presentation/pages/confirmation_page.dart';
import 'package:qent/features/home/domain/models/car.dart';

/// Formats card number input: adds space every 4 digits, max 16 digits
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    final trimmed = digitsOnly.length > 16 ? digitsOnly.substring(0, 16) : digitsOnly;
    final buffer = StringBuffer();
    for (int i = 0; i < trimmed.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(trimmed[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Formats expiry input: auto-inserts "/" after 2 digits, max MM/YY
class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    final trimmed = digitsOnly.length > 4 ? digitsOnly.substring(0, 4) : digitsOnly;
    final buffer = StringBuffer();
    for (int i = 0; i < trimmed.length; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(trimmed[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class PaymentMethodsPage extends StatefulWidget {
  final Car car;
  final BookingConfirmation confirmationData;

  const PaymentMethodsPage({
    super.key,
    required this.car,
    required this.confirmationData,
  });

  @override
  State<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends State<PaymentMethodsPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvcController = TextEditingController();
  final _zipController = TextEditingController();

  final _cardNumberFocus = FocusNode();
  final _expiryFocus = FocusNode();
  final _cvcFocus = FocusNode();

  PaymentMethodType _selectedPaymentMethod = PaymentMethodType.card;
  String? _selectedCountry = 'Nigeria';
  bool _termsAccepted = true;
  bool _isLoading = false;
  CardBrand _detectedBrand = CardBrand.unknown;
  bool _showCardBack = false;

  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  final List<String> _countries = [
    'Nigeria',
    'United States',
    'United Kingdom',
    'Canada',
    'Germany',
    'France',
    'Ghana',
    'South Africa',
  ];

  @override
  void initState() {
    super.initState();

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutBack),
    );

    _cardNumberController.addListener(_onCardNumberChanged);
    _cvcFocus.addListener(_onCvcFocusChanged);
  }

  void _onCardNumberChanged() {
    final text = _cardNumberController.text;
    final brand = CardInfo.detectBrand(text);
    if (brand != _detectedBrand) {
      setState(() => _detectedBrand = brand);
    } else {
      setState(() {});
    }
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 16) {
      _expiryFocus.requestFocus();
    }
  }

  void _onCvcFocusChanged() {
    if (_cvcFocus.hasFocus && !_showCardBack) {
      setState(() => _showCardBack = true);
      _flipController.forward();
    } else if (!_cvcFocus.hasFocus && _showCardBack) {
      setState(() => _showCardBack = false);
      _flipController.reverse();
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvcController.dispose();
    _zipController.dispose();
    _cardNumberFocus.dispose();
    _expiryFocus.dispose();
    _cvcFocus.dispose();
    _flipController.dispose();
    super.dispose();
  }

  // Premium gradient palettes per brand
  List<Color> _brandGradientColors() {
    switch (_detectedBrand) {
      case CardBrand.visa:
        return [const Color(0xFF0D1B6F), const Color(0xFF1A3AC7), const Color(0xFF4A6CF7)];
      case CardBrand.mastercard:
        return [const Color(0xFF1A1A2E), const Color(0xFFEB001B), const Color(0xFFF79E1B)];
      case CardBrand.verve:
        return [const Color(0xFF00263A), const Color(0xFF00425F), const Color(0xFF00A676)];
      case CardBrand.unknown:
        return [const Color(0xFF0F0F0F), const Color(0xFF1A1A2E), const Color(0xFF2D2D44)];
    }
  }

  String? _brandSvgAsset() {
    switch (_detectedBrand) {
      case CardBrand.visa:
        return 'assets/images/card_brands/visa.svg';
      case CardBrand.mastercard:
        return 'assets/images/card_brands/mastercard.svg';
      case CardBrand.verve:
        return 'assets/images/card_brands/verve.svg';
      case CardBrand.unknown:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context),
            _buildStepper(activeStep: 1),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      _buildLiveCardPreview(),
                      const SizedBox(height: 28),
                      _buildSelectPaymentMethodSection(),
                      const SizedBox(height: 24),
                      _buildCardInformationSection(),
                      const SizedBox(height: 24),
                      _buildCountrySection(),
                      const SizedBox(height: 24),
                      _buildTermsCheckbox(),
                      const SizedBox(height: 24),
                      _buildAlternativePaymentMethods(),
                      SizedBox(height: screenHeight * 0.15),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildContinueButton(context, screenWidth),
    ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.arrow_back_rounded, size: 20, color: Color(0xFF1A1A1A)),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Payment Methods',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
          ),
          const SizedBox(width: 42),
        ],
      ),
    );
  }

  Widget _buildStepper({required int activeStep}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Column(
        children: [
          Row(
            children: [
              _buildStepCircle(0, activeStep),
              Expanded(child: Container(height: 2, color: activeStep > 0 ? const Color(0xFF1A1A1A) : Colors.grey[300])),
              _buildStepCircle(1, activeStep),
              Expanded(child: Container(height: 2, color: activeStep > 1 ? const Color(0xFF1A1A1A) : Colors.grey[300])),
              _buildStepCircle(2, activeStep),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Details', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: Colors.grey[500])),
              Text('Payment', style: TextStyle(fontSize: 11, fontWeight: activeStep == 1 ? FontWeight.w600 : FontWeight.w400, color: activeStep == 1 ? const Color(0xFF1A1A1A) : Colors.grey[500])),
              Text('Confirm', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: Colors.grey[500])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepCircle(int step, int activeStep) {
    final isCompleted = step < activeStep;
    final isActive = step == activeStep;

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: (isActive || isCompleted) ? const Color(0xFF1A1A1A) : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: (isActive || isCompleted) ? const Color(0xFF1A1A1A) : Colors.grey[300]!,
          width: 2,
        ),
      ),
      child: Center(
        child: isCompleted
            ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
            : Text(
                '${step + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : Colors.grey[500],
                ),
              ),
      ),
    );
  }

  // ─── PREMIUM CARD PREVIEW ─────────────────────────────────────────
  Widget _buildLiveCardPreview() {
    final rawDigits = _cardNumberController.text.replaceAll(RegExp(r'\D'), '');
    final String cardNumber;
    if (rawDigits.isEmpty) {
      cardNumber = '**** **** **** ****';
    } else if (rawDigits.length < 4) {
      cardNumber = '**** **** **** ${rawDigits.padRight(4, '*')}';
    } else {
      final last4 = rawDigits.substring(rawDigits.length - 4);
      cardNumber = '**** **** **** $last4';
    }
    final cardName = _fullNameController.text.isEmpty
        ? 'YOUR NAME'
        : _fullNameController.text.toUpperCase();
    final expiry = _expiryController.text.isEmpty
        ? 'MM/YY'
        : _expiryController.text;
    final cvc = _cvcController.text.isEmpty ? '***' : _cvcController.text;

    return AnimatedBuilder(
      animation: _flipAnimation,
      builder: (context, child) {
        final angle = _flipAnimation.value * math.pi;
        final isFront = angle < math.pi / 2;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0015)
            ..rotateY(angle),
          child: isFront
              ? _buildCardFront(cardNumber, cardName, expiry)
              : Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(math.pi),
                  child: _buildCardBack(cvc),
                ),
        );
      },
    );
  }

  Widget _buildCardFront(String cardNumber, String cardName, String expiry) {
    final gradientColors = _brandGradientColors();
    final svgAsset = _brandSvgAsset();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      height: 210,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: gradientColors[1].withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 14),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: gradientColors[0].withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Base gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),

            // Large decorative circle (top-right)
            Positioned(
              top: -40,
              right: -30,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.12),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),

            // Small decorative circle (bottom-left)
            Positioned(
              bottom: -50,
              left: -20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.08),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),

            // Subtle diagonal line pattern overlay
            Positioned.fill(
              child: CustomPaint(painter: _CardPatternPainter()),
            ),

            // Noise texture overlay for premium tactile feel
            Positioned.fill(
              child: CustomPaint(painter: _NoisePainter()),
            ),

            // Glassmorphism frosted panel overlay
            Positioned(
              top: 70,
              left: 0,
              right: 0,
              height: 70,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.0),
                          Colors.white.withValues(alpha: 0.05),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Shimmering edge highlight (gradient border glow)
            Positioned.fill(
              child: CustomPaint(painter: _EdgeHighlightPainter()),
            ),

            // Card content
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: chip + brand logo
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // EMV Chip
                      Container(
                        width: 42,
                        height: 32,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFD4A843), Color(0xFFF7DC6F), Color(0xFFD4A843)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // Chip lines
                            Positioned(
                              top: 8,
                              left: 4,
                              right: 4,
                              child: Container(height: 1, color: const Color(0xFFC49B30).withValues(alpha: 0.5)),
                            ),
                            Positioned(
                              top: 16,
                              left: 4,
                              right: 4,
                              child: Container(height: 1, color: const Color(0xFFC49B30).withValues(alpha: 0.5)),
                            ),
                            Positioned(
                              top: 24,
                              left: 4,
                              right: 4,
                              child: Container(height: 1, color: const Color(0xFFC49B30).withValues(alpha: 0.5)),
                            ),
                            Positioned(
                              left: 14,
                              top: 4,
                              bottom: 4,
                              child: Container(width: 1, color: const Color(0xFFC49B30).withValues(alpha: 0.5)),
                            ),
                            Positioned(
                              left: 28,
                              top: 4,
                              bottom: 4,
                              child: Container(width: 1, color: const Color(0xFFC49B30).withValues(alpha: 0.5)),
                            ),
                          ],
                        ),
                      ),

                      // Contactless icon
                      Icon(
                        Icons.contactless_outlined,
                        color: Colors.white.withValues(alpha: 0.6),
                        size: 24,
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Card number
                  Text(
                    cardNumber,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w500,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Bottom row: name + expiry + brand logo
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CARD HOLDER',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              cardName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'EXPIRES',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            expiry,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      // Brand SVG logo
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: svgAsset != null
                            ? SvgPicture.asset(
                                svgAsset,
                                key: ValueKey(svgAsset),
                                width: 52,
                                height: 34,
                              )
                            : SizedBox(
                                key: const ValueKey('no-brand'),
                                width: 52,
                                height: 34,
                                child: Center(
                                  child: Icon(
                                    Icons.credit_card_outlined,
                                    color: Colors.white.withValues(alpha: 0.3),
                                    size: 28,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardBack(String cvc) {
    final gradientColors = _brandGradientColors();
    final svgAsset = _brandSvgAsset();

    return Container(
      height: 210,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: gradientColors[1].withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 14),
            spreadRadius: -4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Base gradient (reversed)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomRight,
                  end: Alignment.topLeft,
                  colors: gradientColors,
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),

            // Pattern overlay
            Positioned.fill(
              child: CustomPaint(painter: _CardPatternPainter()),
            ),

            // Noise texture
            Positioned.fill(
              child: CustomPaint(painter: _NoisePainter()),
            ),

            // Edge highlight
            Positioned.fill(
              child: CustomPaint(painter: _EdgeHighlightPainter()),
            ),

            // Content
            Column(
              children: [
                const SizedBox(height: 24),
                // Magnetic strip
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Signature strip + CVC
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Row(
                    children: [
                      // Signature area
                      Expanded(
                        flex: 3,
                        child: Container(
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              // Hatched pattern area
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(4),
                                      bottomLeft: Radius.circular(4),
                                    ),
                                    color: const Color(0xFFF0F0F0),
                                  ),
                                ),
                              ),
                              // CVC display
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  cvc,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1A1A1A),
                                    letterSpacing: 4,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Bottom: brand logo
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'CVV/CVC',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1,
                        ),
                      ),
                      if (svgAsset != null)
                        SvgPicture.asset(
                          svgAsset,
                          width: 44,
                          height: 28,
                          colorFilter: ColorFilter.mode(
                            Colors.white.withValues(alpha: 0.5),
                            BlendMode.srcIn,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── PAYMENT METHOD SELECTION ─────────────────────────────────────
  Widget _buildSelectPaymentMethodSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Payment Method',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildPaymentMethodOption(
              icon: Icons.credit_card,
              label: 'Card',
              type: PaymentMethodType.card,
            ),
            const SizedBox(width: 12),
            _buildPaymentMethodOption(
              icon: Icons.attach_money,
              label: 'Cash',
              type: PaymentMethodType.cash,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentMethodOption({
    required IconData icon,
    required String label,
    required PaymentMethodType type,
  }) {
    final isSelected = _selectedPaymentMethod == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPaymentMethod = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1A1A1A) : const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? const Color(0xFF1A1A1A) : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? Colors.white : Colors.grey[600], size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.grey[600],
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 8),
                const Icon(Icons.check_circle, color: Colors.white, size: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─── CARD INFORMATION FORM ────────────────────────────────────────
  Widget _buildCardInformationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Card Information',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),
        _buildInputField(
          controller: _fullNameController,
          hintText: 'Full Name',
          prefixIcon: Icons.person_outline,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        _buildInputField(
          controller: _emailController,
          hintText: 'Email Address',
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value != null && value.isNotEmpty && !value.contains('@')) {
              return 'Enter a valid email';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        _buildInputField(
          controller: _cardNumberController,
          hintText: 'Card Number',
          prefixIcon: Icons.credit_card,
          keyboardType: TextInputType.number,
          focusNode: _cardNumberFocus,
          formatters: [
            FilteringTextInputFormatter.digitsOnly,
            _CardNumberFormatter(),
          ],
          suffixWidget: _buildDetectedBrandBadge(),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildInputField(
                controller: _expiryController,
                hintText: 'MM/YY',
                prefixIcon: Icons.calendar_today_outlined,
                keyboardType: TextInputType.number,
                focusNode: _expiryFocus,
                formatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _ExpiryDateFormatter(),
                ],
                onChanged: (value) {
                  final digits = value.replaceAll(RegExp(r'\D'), '');
                  if (digits.length == 4) {
                    _cvcFocus.requestFocus();
                  }
                },
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final parts = value.split('/');
                    if (parts.length == 2) {
                      final month = int.tryParse(parts[0]) ?? 0;
                      if (month < 1 || month > 12) return 'Invalid month';
                    }
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInputField(
                controller: _cvcController,
                hintText: 'CVC',
                prefixIcon: Icons.lock_outline,
                keyboardType: TextInputType.number,
                focusNode: _cvcFocus,
                obscureText: true,
                formatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetectedBrandBadge() {
    if (_detectedBrand == CardBrand.unknown) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset('assets/images/card_brands/visa.svg', width: 28, height: 18),
          const SizedBox(width: 4),
          SvgPicture.asset('assets/images/card_brands/mastercard.svg', width: 28, height: 18),
          const SizedBox(width: 4),
          SvgPicture.asset('assets/images/card_brands/verve.svg', width: 28, height: 18),
        ],
      );
    }
    final svgAsset = _brandSvgAsset()!;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: SvgPicture.asset(
        svgAsset,
        key: ValueKey(svgAsset),
        width: 40,
        height: 26,
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    IconData? prefixIcon,
    TextInputType? keyboardType,
    FocusNode? focusNode,
    bool obscureText = false,
    List<TextInputFormatter>? formatters,
    Widget? suffixWidget,
    ValueChanged<String>? onChanged,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        focusNode: focusNode,
        obscureText: obscureText,
        inputFormatters: formatters,
        textInputAction: TextInputAction.next,
        onChanged: onChanged,
        validator: validator,
        style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, color: Colors.grey[500], size: 20)
              : null,
          suffixIcon: suffixWidget != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: suffixWidget,
                )
              : null,
          suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        ),
      ),
    );
  }

  // ─── COUNTRY SECTION ──────────────────────────────────────────────
  Widget _buildCountrySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Country or Region',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(14),
          ),
          child: DropdownButtonFormField<String>(
            initialValue: _selectedCountry,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 14),
            ),
            items: _countries.map((country) {
              return DropdownMenuItem(
                value: country,
                child: Text(
                  country,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedCountry = value);
              }
            },
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey[500]),
          ),
        ),
        const SizedBox(height: 14),
        _buildInputField(
          controller: _zipController,
          hintText: 'ZIP / Postal Code',
          prefixIcon: Icons.pin_drop_outlined,
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  Widget _buildTermsCheckbox() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => setState(() => _termsAccepted = !_termsAccepted),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: _termsAccepted ? const Color(0xFF1A1A1A) : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _termsAccepted ? const Color(0xFF1A1A1A) : Colors.grey[400]!,
                width: 1.5,
              ),
            ),
            child: _termsAccepted
                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            children: [
              const Text(
                'Terms & Conditions',
                style: TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
              ),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.grey[500]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAlternativePaymentMethods() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey[300])),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Pay with card Or',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey[300])),
          ],
        ),
        const SizedBox(height: 16),
        _buildPaymentButton(
          icon: Icons.apple,
          label: 'Apple Pay',
          onTap: () => setState(() => _selectedPaymentMethod = PaymentMethodType.applePay),
        ),
        const SizedBox(height: 12),
        _buildPaymentButton(
          icon: Icons.payment_rounded,
          label: 'Paystack',
          onTap: () => setState(() => _selectedPaymentMethod = PaymentMethodType.paystack),
        ),
      ],
    );
  }

  Widget _buildPaymentButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF1A1A1A), size: 24),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePayment() async {
    if (!(_formKey.currentState!.validate() && _termsAccepted)) return;

    setState(() => _isLoading = true);

    try {
      // All payments go through Paystack
      final response = await ApiClient().post('/payments/initiate', body: {
        'booking_id': widget.confirmationData.bookingId,
      });

      if (!mounted) return;

      if (response.isSuccess) {
        final paymentInit = PaymentInitResponse.fromJson(
          response.body as Map<String, dynamic>,
        );

        final updated = widget.confirmationData.copyWith(
          paymentMethod: 'Paystack',
          paymentReference: paymentInit.reference,
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConfirmationPage(
              car: widget.car,
              confirmation: updated,
              authorizationUrl: paymentInit.authorizationUrl,
            ),
          ),
        );
      } else {
        _showError(response.errorMessage);
      }
    } catch (e) {
      if (mounted) _showError('Payment failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildContinueButton(BuildContext context, double screenWidth) {
    return Container(
      padding: EdgeInsets.only(
        left: screenWidth * 0.05,
        right: screenWidth * 0.05,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handlePayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A1A1A),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[400],
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Continue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

/// Custom painter for subtle diagonal line pattern on the card
class _CardPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const spacing = 20.0;
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom painter for gradient edge highlight (light source simulation)
class _EdgeHighlightPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const radius = 22.0;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(radius),
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = ui.Gradient.sweep(
        Offset(size.width / 2, size.height / 2),
        [
          Colors.white.withValues(alpha: 0.18), // top
          Colors.white.withValues(alpha: 0.10), // right
          Colors.white.withValues(alpha: 0.02), // bottom
          Colors.white.withValues(alpha: 0.06), // left
          Colors.white.withValues(alpha: 0.18), // back to top
        ],
        [0.0, 0.25, 0.5, 0.75, 1.0],
      );

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom painter for fine noise/grain texture overlay (premium tactile feel)
class _NoisePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42); // Fixed seed for consistent pattern
    final paint = Paint()..style = PaintingStyle.fill;
    const density = 0.12; // Percentage of pixels to draw
    final totalDots = (size.width * size.height * density).toInt();

    for (int i = 0; i < totalDots; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final brightness = rng.nextDouble();
      paint.color = brightness > 0.5
          ? Colors.white.withValues(alpha: 0.04 + rng.nextDouble() * 0.03)
          : Colors.black.withValues(alpha: 0.03 + rng.nextDouble() * 0.02);
      canvas.drawCircle(Offset(x, y), 0.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
