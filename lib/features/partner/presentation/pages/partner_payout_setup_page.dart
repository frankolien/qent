import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qent/core/services/api_client.dart';
import 'package:qent/features/home/presentation/providers/car_providers.dart';

class PartnerPayoutSetupPage extends ConsumerStatefulWidget {
  const PartnerPayoutSetupPage({super.key});

  @override
  ConsumerState<PartnerPayoutSetupPage> createState() => _PartnerPayoutSetupPageState();
}

class _PartnerPayoutSetupPageState extends ConsumerState<PartnerPayoutSetupPage> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvcController = TextEditingController();
  final _zipController = TextEditingController();
  String _selectedCountry = 'Nigeria';
  bool _acceptedTerms = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvcController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    setState(() => _isSubmitting = true);

    try {
      // Activate the partner's car listing
      await ApiClient().post('/partner/activate-car', body: {});
    } catch (_) {
      // Car can be activated later by admin if this fails
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    // Refresh cars on the homepage
    ref.invalidate(carsProvider);

    // Show congratulations
    _showCongratulations();
  }

  void _showCongratulations() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              'Congratulations',
              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black),
            ),
            const SizedBox(height: 12),
            Text(
              'Your car is ready for booking. Your listing has been successfully added to the platform. Get ready to start earning.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600], height: 1.5),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2C2C2C),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).popUntil((route) => route.settings.name == '/home' || route.isFirst);
                },
                child: Text(
                  'Back to Home',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.black, size: 18),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Payment receive methods',
          style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 16),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Verify success banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FFF0),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.verified_rounded, color: Colors.green, size: 32),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Successful',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your OTP verification was successful. You can proceed with your account setup or booking process.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600], height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Credit card preview
              _buildCardPreview(),
              const SizedBox(height: 24),

              // Payment method selector
              Text(
                'select payment receive method',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[700]),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, size: 20, color: Colors.grey[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Cash payment', style: GoogleFonts.inter(fontSize: 14, color: Colors.black87)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('DEFAULT', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Card information
              Text(
                'Card information',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black),
              ),
              const SizedBox(height: 16),
              _buildTextField(label: 'Full Name', controller: _fullNameController),
              const SizedBox(height: 14),
              _buildTextField(label: 'Email Address', controller: _emailController, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 14),
              _buildTextField(
                label: 'Number',
                controller: _cardNumberController,
                keyboardType: TextInputType.number,
                suffix: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.credit_card, size: 18, color: Colors.blue[600]),
                    const SizedBox(width: 4),
                    Icon(Icons.credit_card, size: 18, color: Colors.orange[600]),
                    const SizedBox(width: 4),
                    Icon(Icons.credit_card, size: 18, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Icon(Icons.credit_card, size: 18, color: Colors.grey[400]),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _buildTextField(label: 'MM / YY', controller: _expiryController, keyboardType: TextInputType.datetime)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      label: 'CVC',
                      controller: _cvcController,
                      keyboardType: TextInputType.number,
                      suffix: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Icon(Icons.credit_card, size: 18, color: Colors.grey[500]),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Country
              Text(
                'Country or region',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCountry,
                    isExpanded: true,
                    icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
                    style: GoogleFonts.inter(fontSize: 14, color: Colors.black87),
                    items: const [
                      DropdownMenuItem(value: 'Nigeria', child: Text('Nigeria')),
                      DropdownMenuItem(value: 'United States', child: Text('United States')),
                      DropdownMenuItem(value: 'United Kingdom', child: Text('United Kingdom')),
                      DropdownMenuItem(value: 'Ghana', child: Text('Ghana')),
                      DropdownMenuItem(value: 'Kenya', child: Text('Kenya')),
                    ],
                    onChanged: (v) => setState(() => _selectedCountry = v ?? 'Nigeria'),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _buildTextField(label: 'ZIP', controller: _zipController, keyboardType: TextInputType.number),
              const SizedBox(height: 20),

              // Terms
              Row(
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Checkbox(
                      value: _acceptedTerms,
                      onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                      activeColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    children: [
                      Text('Terms & continue', style: GoogleFonts.inter(fontSize: 13, color: Colors.black87)),
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey[600]),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Separator
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey[300])),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Receive with card Or', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[500])),
                  ),
                  Expanded(child: Divider(color: Colors.grey[300])),
                ],
              ),
              const SizedBox(height: 16),

              // Apple Pay / Google Pay
              _buildPayButton(icon: Icons.apple, label: 'Apple pay'),
              const SizedBox(height: 10),
              _buildPayButton(icon: Icons.g_mobiledata, label: 'Google Pay'),
              const SizedBox(height: 28),

              // Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C2C2C),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'Submit',
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardPreview() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2C2C2C), Color(0xFF1A1A1A)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red.withValues(alpha: 0.8),
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(-10, 0),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.orange.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
              Text('VISA', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, fontStyle: FontStyle.italic)),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            width: 36,
            height: 26,
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _fullNameController.text.isEmpty ? 'YOUR NAME' : _fullNameController.text.toUpperCase(),
                style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1),
              ),
              Text(
                'Expire: ${_expiryController.text.isEmpty ? 'MM/YY' : _expiryController.text}',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _formatCardNumber(_cardNumberController.text),
            style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500, letterSpacing: 3),
          ),
        ],
      ),
    );
  }

  String _formatCardNumber(String number) {
    if (number.isEmpty) return '•••• •••• •••• ••••';
    final clean = number.replaceAll(RegExp(r'\D'), '');
    final padded = clean.padRight(16, '•');
    return '${padded.substring(0, 4)} ${padded.substring(4, 8)} ${padded.substring(8, 12)} ${padded.substring(12, 16)}';
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(fontSize: 14),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: Colors.grey[500], fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black54)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildPayButton({required IconData icon, required String label}) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.grey[100],
          foregroundColor: Colors.black,
          side: BorderSide(color: Colors.grey[300]!),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: () {},
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
