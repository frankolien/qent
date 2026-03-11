import 'package:flutter/material.dart';
import 'package:qent/features/booking/domain/models/booking_confirmation.dart';
import 'package:qent/features/booking/domain/models/payment_method.dart';
import 'package:qent/features/booking/presentation/pages/confirmation_page.dart';
import 'package:qent/features/home/domain/models/car.dart';

class PaymentMethodsPage extends StatefulWidget {
  final Car car;
  final BookingConfirmation confirmationData;

  PaymentMethodsPage({
    super.key,
    required this.car,
    required this.confirmationData,
  });

  @override
  State<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends State<PaymentMethodsPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _expiryMonthController = TextEditingController();
  final _expiryYearController = TextEditingController();
  final _cvcController = TextEditingController();
  final _zipController = TextEditingController();

  PaymentMethodType? _selectedPaymentMethod;
  String? _selectedCountry;
  bool _termsAccepted = true;

  final List<String> _countries = [
    'United States',
    'United Kingdom',
    'Canada',
    'Nigeria',
    'Germany',
    'France',
    'Spain',
    'Italy',
  ];

  @override
  void initState() {
    super.initState();
    _selectedPaymentMethod = PaymentMethodType.cash;
    _selectedCountry = 'United States';
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _cardNumberController.dispose();
    _expiryMonthController.dispose();
    _expiryYearController.dispose();
    _cvcController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
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
                      _buildCreditCardDisplay(),
                      const SizedBox(height: 24),
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

  Widget _buildCreditCardDisplay() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 25,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 12,
                          child: Container(
                            width: 25,
                            height: 25,
                            decoration: const BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.sim_card, color: Colors.amber[700], size: 30),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'VISA',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '9655 9655 9655 9655',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'BENJAMIN JACK',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                  const Text(
                    'Expire: 10-5-2030',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

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
        GestureDetector(
          onTap: () {
            setState(() {
              _selectedPaymentMethod = PaymentMethodType.cash;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.attach_money, color: Colors.grey[600], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Cash payment',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'DEFAULT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

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
        _buildInputField(controller: _fullNameController, hintText: 'Full Name'),
        const SizedBox(height: 14),
        _buildInputField(controller: _emailController, hintText: 'Email Address', keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 14),
        Stack(
          children: [
            _buildInputField(controller: _cardNumberController, hintText: 'Number', keyboardType: TextInputType.number),
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Row(
                children: [
                  _buildCardLogo('VISA', Colors.blue),
                  const SizedBox(width: 8),
                  _buildCardLogo('MC', Colors.orange),
                  const SizedBox(width: 8),
                  _buildCardLogo('AMEX', Colors.green),
                  const SizedBox(width: 8),
                  _buildCardLogo('D', Colors.blue[900]!),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _buildInputField(controller: _expiryMonthController, hintText: 'MM / YY', keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(
              child: Stack(
                children: [
                  _buildInputField(controller: _cvcController, hintText: 'CVC', keyboardType: TextInputType.number),
                  Positioned(
                    right: 16,
                    top: 0,
                    bottom: 0,
                    child: Icon(Icons.credit_card, color: Colors.grey[500], size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textInputAction: TextInputAction.next,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildCardLogo(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

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
            value: _selectedCountry,
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
                setState(() {
                  _selectedCountry = value;
                });
              }
            },
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey[500]),
          ),
        ),
        const SizedBox(height: 14),
        _buildInputField(controller: _zipController, hintText: 'ZIP', keyboardType: TextInputType.number),
      ],
    );
  }

  Widget _buildTermsCheckbox() {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _termsAccepted = !_termsAccepted;
            });
          },
          child: Container(
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
          onTap: () {
            setState(() {
              _selectedPaymentMethod = PaymentMethodType.applePay;
            });
          },
        ),
        const SizedBox(height: 12),
        _buildPaymentButton(
          icon: Icons.account_circle,
          label: 'Google Pay',
          onTap: () {
            setState(() {
              _selectedPaymentMethod = PaymentMethodType.googlePay;
            });
          },
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
        onPressed: () {
          if (_formKey.currentState!.validate() && _termsAccepted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ConfirmationPage(
                  car: widget.car,
                  confirmation: widget.confirmationData,
                ),
              ),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A1A1A),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: const Text(
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
