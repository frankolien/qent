import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qent/core/services/api_client.dart';
import 'package:qent/core/services/cloudinary_service.dart';
import 'package:qent/core/services/email_verification_service.dart';
import 'package:qent/features/partner/presentation/pages/partner_otp_page.dart';
import 'package:qent/features/partner/presentation/providers/partner_providers.dart';
import 'package:qent/core/theme/app_theme.dart';

class PartnerFormPage extends ConsumerStatefulWidget {
  const PartnerFormPage({super.key});

  @override
  ConsumerState<PartnerFormPage> createState() => _PartnerFormPageState();
}

class _PartnerFormPageState extends ConsumerState<PartnerFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _contactController = TextEditingController();
  final _licenseController = TextEditingController();
  final _registrationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  final _yearController = TextEditingController(text: '2024');

  String? _selectedBrand;
  String? _selectedLuxuryBrand;
  String? _selectedModel;
  String _fuelType = 'Diesel';
  bool _acceptedTerms = true;
  bool _showTermsDetails = false;
  final List<String> _uploadedCarImages = [];
  bool _showBrandSelection = true;
  bool _isSubmitting = false;

  final List<String> _fuelTypes = const ['Electric', 'Petrol', 'Diesel', 'Hybrid'];
  bool _emailValid = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    _licenseController.dispose();
    _registrationController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgPrimary,
      appBar: AppBar(
        backgroundColor: context.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'QENT Partner Program',
          style: GoogleFonts.inter(color: context.textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.more_horiz, color: context.textPrimary),
            onPressed: () {},
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                _buildOwnerInfoCard(),
                const SizedBox(height: 16),
                _buildCarInfoCard(),
                const SizedBox(height: 16),
                _buildTerms(),
                const SizedBox(height: 24),
                _buildSubmitButton(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOwnerInfoCard() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Car Owner Information',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: context.textPrimary, letterSpacing: -0.3),
          ),
          const SizedBox(height: 20),
          _buildInputWithIcon(
            label: 'Full Name',
            controller: _fullNameController,
            icon: Icons.person_outline,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          _buildInputWithIcon(
            label: 'Email Address',
            controller: _emailController,
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            onChanged: (value) {
              final isValid = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value);
              setState(() => _emailValid = isValid && value.isNotEmpty);
            },
            suffixIcon: _emailValid ? const Icon(Icons.check_circle, color: Colors.green, size: 20) : null,
          ),
          const SizedBox(height: 16),
          _buildInputWithIcon(
            label: 'Phone Number',
            controller: _contactController,
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          _buildInputWithIcon(
            label: "Driver's License Number",
            controller: _licenseController,
            icon: Icons.badge_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildCarInfoCard() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Car Information',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: context.textPrimary, letterSpacing: -0.3),
          ),
          const SizedBox(height: 20),
          _buildBrandModelSection(),
          const SizedBox(height: 20),
          _buildCarImageUpload(),
          const SizedBox(height: 20),
          _buildInputWithIcon(
            label: 'Car Registration Number',
            controller: _registrationController,
            icon: Icons.confirmation_number_outlined,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildInputWithIcon(
                  label: 'Year',
                  controller: _yearController,
                  icon: Icons.calendar_today_outlined,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInputWithIcon(
                  label: 'Price per day (₦)',
                  controller: _priceController,
                  icon: Icons.payments_outlined,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInputWithIcon(
            label: 'Location (e.g. Lagos, Abuja)',
            controller: _locationController,
            icon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 20),
          _buildFuelSection(),
          const SizedBox(height: 20),
          _buildDescription(),
        ],
      ),
    );
  }

  Widget _buildBrandModelSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Car Brand & Model',
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: context.bgSecondary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _showBrandSelection = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _showBrandSelection ? context.textPrimary : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Car Brand',
                      style: GoogleFonts.inter(
                        color: _showBrandSelection ? context.bgPrimary : context.textPrimary,
                        fontWeight: _showBrandSelection ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () {
                    if ((_selectedBrand != null || _selectedLuxuryBrand != null)) {
                      setState(() => _showBrandSelection = false);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: !_showBrandSelection ? context.textPrimary : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Car Model',
                      style: GoogleFonts.inter(
                        color: !_showBrandSelection ? context.bgPrimary : context.textPrimary,
                        fontWeight: !_showBrandSelection ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_showBrandSelection)
          _StaticBrandLists(
            regularBrands: ref.watch(regularBrandsProvider),
            luxuryBrands: ref.watch(luxuryBrandsProvider),
            selectedRegular: _selectedBrand,
            selectedLuxury: _selectedLuxuryBrand,
            onSelectRegular: (v) {
              setState(() {
                _selectedBrand = v;
                _selectedLuxuryBrand = null;
                _selectedModel = null;
                _showBrandSelection = false;
              });
            },
            onSelectLuxury: (v) {
              setState(() {
                _selectedLuxuryBrand = v;
                _selectedBrand = null;
                _selectedModel = null;
                _showBrandSelection = false;
              });
            },
          )
        else if (_selectedBrand != null || _selectedLuxuryBrand != null)
          _StaticModelsList(
            brandName: _selectedBrand ?? _selectedLuxuryBrand!,
            models: ref.watch(modelsProvider(_selectedBrand ?? _selectedLuxuryBrand!)),
            selectedModel: _selectedModel,
            onSelectModel: (m) {
              setState(() => _selectedModel = m);
            },
          ),
        if (_selectedBrand != null || _selectedLuxuryBrand != null) ...[
          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              if (_selectedModel == null) {
                setState(() => _showBrandSelection = false);
              } else {
                setState(() => _showBrandSelection = true);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: context.bgSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.borderColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        _selectedBrand != null ? 'Regular AUTO' : 'Luxury',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(width: 8),
                      Text('/', style: GoogleFonts.inter(color: Colors.grey[600])),
                      const SizedBox(width: 8),
                      Text(
                        _selectedBrand ?? _selectedLuxuryBrand ?? '',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      if (_selectedModel != null) ...[
                        const SizedBox(width: 8),
                        Text('/', style: GoogleFonts.inter(color: Colors.grey[600])),
                        const SizedBox(width: 8),
                        Text(
                          _selectedModel!,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ],
                    ],
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    // pickMultiImage lets the user select many photos at once from the gallery.
    final picked = await picker.pickMultiImage(imageQuality: 85);
    if (picked.isNotEmpty) {
      setState(() {
        _uploadedCarImages.addAll(picked.map((x) => x.path));
      });
    }
  }

  Future<void> _pickFromCamera() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (picked != null) {
      setState(() => _uploadedCarImages.add(picked.path));
    }
  }

  Widget _buildCarImageUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: _pickFromGallery,
                child: Row(
                  children: [
                    Icon(Icons.photo_library_outlined, color: Colors.grey[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Upload at least 2 car images',
                      style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[700], fontWeight: FontWeight.w400),
                    ),
                  ],
                ),
              ),
            ),
            // Camera shortcut — single shot
            IconButton(
              tooltip: 'Take photo',
              onPressed: _pickFromCamera,
              icon: Icon(Icons.photo_camera_outlined, color: Colors.grey[700], size: 22),
            ),
          ],
        ),
        if (_uploadedCarImages.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _uploadedCarImages.asMap().entries.map((entry) {
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(entry.value),
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: InkWell(
                      onTap: () => setState(() => _uploadedCarImages.removeAt(entry.key)),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildFuelSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fuel Type',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: context.textPrimary),
        ),
        const SizedBox(height: 16),
        Row(
          children: _fuelTypes.map((t) {
            final bool sel = _fuelType == t;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: _fuelTypes.indexOf(t) < _fuelTypes.length - 1 ? 8 : 0),
                child: InkWell(
                  onTap: () => setState(() => _fuelType = t),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: sel ? context.textPrimary : context.bgPrimary,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: sel ? context.textPrimary : context.borderColor,
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      t,
                      style: GoogleFonts.inter(
                        color: sel ? context.bgPrimary : context.textSecondary,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _descriptionController,
          maxLines: 6,
          maxLength: 1000,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Enter your car ability, durability, etc message here.......',
            hintStyle: GoogleFonts.inter(color: context.textTertiary, fontSize: 15),
            filled: true,
            fillColor: context.inputBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.inputBorder, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.inputBorder, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.textSecondary, width: 1),
            ),
            contentPadding: const EdgeInsets.all(16),
            counterText: '${_descriptionController.text.length}/1000',
            counterStyle: GoogleFonts.inter(color: context.textSecondary, fontSize: 12),
          ),
          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w400, color: context.textPrimary),
          onChanged: (value) {
            setState(() {});
          },
        ),
      ],
    );
  }

  Widget _buildTerms() {
    return InkWell(
      onTap: () => setState(() => _showTermsDetails = !_showTermsDetails),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: _acceptedTerms,
                onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                activeColor: context.textPrimary,
                checkColor: context.bgPrimary,
              ),
              Text(
                'Terms & Conditions',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: context.textPrimary),
              ),
              const SizedBox(width: 4),
              Icon(
                _showTermsDetails ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                size: 20,
                color: context.textSecondary,
              ),
            ],
          ),
          if (_showTermsDetails)
            Padding(
              padding: const EdgeInsets.only(left: 48, right: 16, bottom: 8),
              child: Text(
                'By submitting this form, you agree to QENT\'s partner terms and conditions...',
                style: GoogleFonts.inter(fontSize: 12, color: context.textSecondary, height: 1.4),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: context.textPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 18),
          elevation: 2,
        ),
        onPressed: _isSubmitting ? null : _handleSubmit,
        child: _isSubmitting
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: context.bgPrimary),
              )
            : Text(
                'Submit',
                style: GoogleFonts.inter(color: context.bgPrimary, fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: 0.5),
              ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please accept the Terms & Conditions', style: GoogleFonts.inter())),
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final brand = _selectedBrand ?? _selectedLuxuryBrand;
    if (brand == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a car brand', style: GoogleFonts.inter())),
      );
      return;
    }
    if (_selectedModel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a car model', style: GoogleFonts.inter())),
      );
      return;
    }
    if (_priceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a price per day', style: GoogleFonts.inter())),
      );
      return;
    }
    if (_locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a location', style: GoogleFonts.inter())),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Upload photos to Cloudinary first
      final cloudinary = CloudinaryService();
      final uploadedUrls = <String>[];

      for (final path in _uploadedCarImages) {
        final url = await cloudinary.uploadImage(
          imageFile: File(path),
          folder: 'qent/cars',
        );
        if (url != null) {
          uploadedUrls.add(url);
        }
      }

      if (uploadedUrls.isEmpty && _uploadedCarImages.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload photos. Please try again.', style: GoogleFonts.inter())),
          );
          setState(() => _isSubmitting = false);
        }
        return;
      }

      final response = await ApiClient().post('/partner/apply', body: {
        'full_name': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _contactController.text.trim(),
        'drivers_license': _licenseController.text.trim(),
        'car_make': brand,
        'car_model': _selectedModel!,
        'car_year': int.tryParse(_yearController.text.trim()) ?? 2024,
        // Color is no longer collected from the host — backend still requires
        // a non-empty string so we send a placeholder.
        'car_color': 'N/A',
        'car_plate_number': _registrationController.text.trim(),
        'car_photos': uploadedUrls,
        'car_description': _descriptionController.text.trim(),
        'fuel_type': _fuelType.toLowerCase(),
        'price_per_day': double.tryParse(_priceController.text.trim()) ?? 0.0,
        'location': _locationController.text.trim(),
      });

      if (!mounted) return;

      if (response.isSuccess) {
        // Save the new JWT token with Host role
        final newToken = response.body['token'] as String?;
        if (newToken != null && newToken.isNotEmpty) {
          await ApiClient().setToken(newToken);
        }

        // Send OTP to the partner's email
        final email = _emailController.text.trim();
        final verificationService = EmailVerificationService();
        await verificationService.sendVerificationCode(email);

        if (!mounted) return;

        // Navigate to OTP page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PartnerOtpPage(email: email),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.errorMessage, style: GoogleFonts.inter()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Something went wrong. Please try again.', style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildInputWithIcon({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    Widget? suffixIcon,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: context.textSecondary, fontWeight: FontWeight.w400),
        prefixIcon: Icon(icon, color: context.textSecondary),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.inputBorder, width: 1),
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: context.inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w400, color: context.textPrimary),
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
      onChanged: onChanged,
    );
  }
}

class _StaticBrandLists extends StatelessWidget {
  const _StaticBrandLists({
    required this.regularBrands,
    required this.luxuryBrands,
    this.selectedRegular,
    this.selectedLuxury,
    required this.onSelectRegular,
    required this.onSelectLuxury,
  });
  final List<String> regularBrands;
  final List<String> luxuryBrands;
  final String? selectedRegular;
  final String? selectedLuxury;
  final ValueChanged<String> onSelectRegular;
  final ValueChanged<String> onSelectLuxury;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: context.bgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _BrandsColumn(
              title: 'Regular Cars Brand',
              items: regularBrands,
              onTap: onSelectRegular,
              selected: selectedRegular,
            ),
          ),
          Container(width: 1, height: 240, color: context.borderColor),
          Expanded(
            child: _BrandsColumn(
              title: 'Luxury Cars Brand',
              items: luxuryBrands,
              onTap: onSelectLuxury,
              selected: selectedLuxury,
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandsColumn extends StatelessWidget {
  const _BrandsColumn({required this.title, required this.items, required this.onTap, this.selected});
  final String title;
  final List<String> items;
  final ValueChanged<String> onTap;
  final String? selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: context.textPrimary)),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (ctx, index) {
                final e = items[index];
                final bool isSel = selected == e;
                return InkWell(
                  onTap: () => onTap(e),
                  child: Container(
                    height: 36,
                    alignment: Alignment.centerLeft,
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isSel ? context.textPrimary.withValues(alpha: 0.08) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(e, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: context.textPrimary))),
                        if (isSel) Icon(Icons.check, size: 16, color: context.textPrimary),
                      ],
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}

class _StaticModelsList extends StatelessWidget {
  const _StaticModelsList({required this.brandName, required this.models, required this.selectedModel, required this.onSelectModel});
  final String brandName;
  final List<String> models;
  final String? selectedModel;
  final ValueChanged<String> onSelectModel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.bgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Models for $brandName', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: context.textPrimary)),
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: models.isEmpty
                ? Center(child: Text('No models available', style: GoogleFonts.inter(color: context.textTertiary)))
                : ListView.builder(
                    itemCount: models.length,
                    itemBuilder: (ctx, index) {
                      final e = models[index];
                      final bool isSel = e == selectedModel;
                      return InkWell(
                        onTap: () => onSelectModel(e),
                        child: Container(
                          height: 36,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: isSel ? context.textPrimary.withValues(alpha: 0.08) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(child: Text(e, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: context.textPrimary))),
                              if (isSel) Icon(Icons.check, size: 16, color: context.textPrimary),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
