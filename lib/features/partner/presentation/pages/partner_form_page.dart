import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:qent/core/services/cloudinary_service.dart';
import 'package:qent/features/partner/presentation/pages/partner_otp_page.dart';
import 'package:qent/features/partner/presentation/providers/partner_providers.dart';

class PartnerFormPage extends StatefulWidget {
  const PartnerFormPage({super.key});

  @override
  State<PartnerFormPage> createState() => _PartnerFormPageState();
}

class _PartnerFormPageState extends State<PartnerFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _contactController = TextEditingController();
  final _licenseController = TextEditingController();
  final _registrationController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedBrand;
  String? _selectedLuxuryBrand;
  String? _selectedModel;
  String? _selectedColor = 'Blue';
  String _fuelType = 'Diesel';
  bool _acceptedTerms = true;
  bool _showTermsDetails = false;
  List<String> _uploadedCarImages = [];
  bool _showBrandSelection = true; // true for brand, false for model

  final List<Map<String, dynamic>> _colors = const [
    {'name': 'White', 'color': Colors.white},
    {'name': 'Gray', 'color': Color(0xFFBDBDBD)},
    {'name': 'Blue', 'color': Color(0xFF2962FF)},
    {'name': 'Black', 'color': Colors.black},
    {'name': 'Red', 'color': Color(0xFFD32F2F)},
    {'name': 'Silver', 'color': Color(0xFFC0C0C0)},
    {'name': 'Green', 'color': Color(0xFF4CAF50)},
    {'name': 'Yellow', 'color': Color(0xFFFFEB3B)},
  ];

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:  Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'QENT Partner Program',
          style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 16),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.black),
            onPressed: () {
              // Show overflow menu
            },
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
                _AvatarUploader(
                  onUploaded: (url) async {
                    final user = fb.FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      // Save to both field names for consistency
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .set({
                        'photoUrl': url,
                        'profileImageUrl': url,
                      }, SetOptions(merge: true));
                      
                      // Also update Firebase Auth photo URL
                      try {
                        await user.updatePhotoURL(url);
                      } catch (e) {
                        debugPrint('Error updating Firebase Auth photo URL: $e');
                      }
                    }
                  },
                ),
                const SizedBox(height: 32),
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
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black, letterSpacing: -0.3),
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
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black, letterSpacing: -0.3),
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
          _buildColorsSection(),
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
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        const SizedBox(height: 12),
        // Segmented buttons
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
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
                      color: _showBrandSelection ? Colors.black : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Car Brand',
                      style: GoogleFonts.inter(
                        color: _showBrandSelection ? Colors.white : Colors.black87,
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
                      color: !_showBrandSelection ? Colors.black : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Car Model',
                      style: GoogleFonts.inter(
                        color: !_showBrandSelection ? Colors.white : Colors.black87,
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
        // Show brand selection or model selection based on toggle
        if (_showBrandSelection)
          _FirestoreBrandLists(
            selectedRegular: _selectedBrand,
            selectedLuxury: _selectedLuxuryBrand,
            onSelectRegular: (v) async {
              setState(() {
                _selectedBrand = v;
                _selectedLuxuryBrand = null;
                _selectedModel = null;
                _showBrandSelection = false; // Switch to model selection
              });
              await _saveDraftField('brand', v);
            },
            onSelectLuxury: (v) async {
              setState(() {
                _selectedLuxuryBrand = v;
                _selectedBrand = null;
                _selectedModel = null;
                _showBrandSelection = false; // Switch to model selection
              });
              await _saveDraftField('luxuryBrand', v);
            },
          )
        else if (_selectedBrand != null || _selectedLuxuryBrand != null)
          _ModelsList(
            brandName: _selectedBrand ?? _selectedLuxuryBrand!,
            selectedModel: _selectedModel,
            onSelectModel: (m) async {
              setState(() => _selectedModel = m);
              await _saveDraftField('model', m);
            },
          ),
        // Show selected brand/model summary
        if (_selectedBrand != null || _selectedLuxuryBrand != null) ...[
          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              if (_selectedModel == null) {
                // Switch to model selection if brand is selected but model isn't
                setState(() => _showBrandSelection = false);
              } else {
                // Switch back to brand selection if both are selected
                setState(() => _showBrandSelection = true);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
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
                      Text(
                        '/',
                        style: GoogleFonts.inter(color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _selectedBrand ?? _selectedLuxuryBrand ?? '',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      if (_selectedModel != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '/',
                          style: GoogleFonts.inter(color: Colors.grey[600]),
                        ),
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

  Widget _buildCarImageUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () async {
            final picker = ImagePicker();
            final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
            if (picked != null) {
              setState(() => _uploadedCarImages.add(picked.path));
            }
          },
          child: Row(
            children: [
              Icon(Icons.photo_camera, color: Colors.grey[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'Upload at least 2 car images',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
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

  Widget _buildColorsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Colors', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black, letterSpacing: -0.3)),
            InkWell(
              onTap: () {
                // Show color picker modal
              },
              child: Text('See All', style: GoogleFonts.inter(fontSize: 14, color: Colors.blue[600], fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _colors.take(7).map((c) {
              final String name = c['name'] as String;
              final Color color = c['color'] as Color;
              final bool sel = _selectedColor == name;
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: InkWell(
                  onTap: () => setState(() => _selectedColor = name),
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                        
                        ),
                        child: sel
                            ? Icon(
                                Icons.check,
                                color: (color == Colors.white || color == const Color(0xFFBDBDBD) || color == const Color(0xFFC0C0C0))
                                    ? Colors.black
                                    : Colors.white,
                                size: 20,
                              )
                            : null,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        name,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                          color: sel ? Colors.black : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFuelSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fuel Type',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
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
                      color: sel ? Colors.black : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: sel ? Colors.black : Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      t,
                      style: GoogleFonts.inter(
                        color: sel ? Colors.white : Colors.grey[600],
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
            hintText: 'Enter your car ability , durability ,etc message here.......',
            hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontSize: 15),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[400]!, width: 1),
            ),
            contentPadding: const EdgeInsets.all(16),
            counterText: '${_descriptionController.text.length}/1000',
            counterStyle: GoogleFonts.inter(color: Colors.grey[600], fontSize: 12),
          ),
          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w400, color: Colors.black87),
          onChanged: (value) {
            setState(() {}); // Update counter
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
                activeColor: Colors.black87,
                checkColor: Colors.white,
              ),
              Text(
                'Trams & continue',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                _showTermsDetails ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                size: 20,
                color: Colors.grey[600],
              ),
            ],
          ),
          if (_showTermsDetails)
            Padding(
              padding: const EdgeInsets.only(left: 48, right: 16, bottom: 8),
              child: Text(
                'By submitting this form, you agree to QENT\'s partner terms and conditions...',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600], height: 1.4),
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
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 18),
          elevation: 2,
        ),
        onPressed: () {
          if (!_acceptedTerms) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Please accept the Terms & Conditions', style: GoogleFonts.inter())),
            );
            return;
          }
          if (_formKey.currentState?.validate() ?? false) {
            _saveDraftField('color', _selectedColor);
            _saveDraftField('fuelType', _fuelType);
            _saveDraftField('fullName', _fullNameController.text.trim());
            _saveDraftField('email', _emailController.text.trim());
            _saveDraftField('contact', _contactController.text.trim());
            _saveDraftField('license', _licenseController.text.trim());
            _saveDraftField('registration', _registrationController.text.trim());
            _saveDraftField('description', _descriptionController.text.trim());
            Navigator.push(context, MaterialPageRoute(builder: (_) => const PartnerOtpPage()));
          }
        },
        child: Text(
          'Submit',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: 0.5),
        ),
      ),
    );
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
        labelStyle: GoogleFonts.inter(color: Colors.grey[700], fontWeight: FontWeight.w400),
        prefixIcon: Icon(icon, color: Colors.grey[600]),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w400),
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
      onChanged: onChanged,
    );
  }

  Future<void> _saveDraftField(String key, dynamic value) async {
    final user = fb.FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('partner_applications')
        .doc(user.uid)
        .set({key: value, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }
}

class _AvatarUploader extends StatefulWidget {
  const _AvatarUploader({required this.onUploaded});
  final ValueChanged<String> onUploaded;

  @override
  State<_AvatarUploader> createState() => _AvatarUploaderState();
}

class _AvatarUploaderState extends State<_AvatarUploader> {
  String? _photoUrl;
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final url = await CloudinaryService().uploadImage(imageFile: File(picked.path), folder: 'qent/profile');
      if (url != null) {
        setState(() => _photoUrl = url);
        widget.onUploaded(url);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadExistingPhoto();
  }

  Future<void> _loadExistingPhoto() async {
    final user = fb.FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // First check Firestore
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      String? url;
      
      if (doc.exists) {
        final data = doc.data();
        // Check both field names: 'photoUrl' (partner form) and 'profileImageUrl' (profile screen)
        url = data?['photoUrl'] as String? ?? data?['profileImageUrl'] as String?;
      }
      
      // Fallback to Firebase Auth photo URL if Firestore doesn't have it
      url ??= user.photoURL;
      
      if (mounted && url != null && url.isNotEmpty) {
        setState(() => _photoUrl = url);
      }
    } catch (e) {
      debugPrint('Error loading existing photo: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.black12,
                backgroundImage: _photoUrl != null
                    ? NetworkImage(_photoUrl!)
                    : const AssetImage('assets/images/image_logo.png') as ImageProvider,
              ),
              InkWell(
                onTap: _uploading ? null : _pickAndUpload,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: _uploading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.photo_camera, size: 18),
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Upload profile photo',
            style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _FirestoreBrandLists extends ConsumerWidget {
  const _FirestoreBrandLists({
    this.selectedRegular,
    this.selectedLuxury,
    required this.onSelectRegular,
    required this.onSelectLuxury,
  });
  final String? selectedRegular;
  final String? selectedLuxury;
  final ValueChanged<String> onSelectRegular;
  final ValueChanged<String> onSelectLuxury;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regularAsync = ref.watch(regularBrandsStreamProvider);
    final luxuryAsync = ref.watch(luxuryBrandsStreamProvider);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              child: _BrandsColumn(
            title: 'Regular Cars Brand',
            asyncList: regularAsync,
            onTap: onSelectRegular,
            selected: selectedRegular,
          )),
          Container(width: 1, height: 240, color: Colors.black12),
          Expanded(
              child: _BrandsColumn(
            title: 'Luxury Cars Brand',
            asyncList: luxuryAsync,
            onTap: onSelectLuxury,
            selected: selectedLuxury,
          )),
        ],
      ),
    );
  }
}

class _BrandsColumn extends StatelessWidget {
  const _BrandsColumn({required this.title, required this.asyncList, required this.onTap, this.selected});
  final String title;
  final AsyncValue<List<String>> asyncList;
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
          Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: asyncList.when(
              data: (items) => ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
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
                        color: isSel ? Colors.black.withOpacity(0.06) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Text(e, style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
                          if (isSel) const Icon(Icons.check, size: 16, color: Colors.black),
                        ],
                      ),
                    ),
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e', style: GoogleFonts.inter(color: Colors.red)),
            ),
          )
        ],
      ),
    );
  }
}

class _ModelsList extends ConsumerWidget {
  const _ModelsList({required this.brandName, required this.selectedModel, required this.onSelectModel});
  final String brandName;
  final String? selectedModel;
  final ValueChanged<String> onSelectModel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelsAsync = ref.watch(modelsStreamProvider(brandName));
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Models for $brandName', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: modelsAsync.when(
              data: (items) => ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final e = items[index];
                  final bool isSel = e == selectedModel;
                  return InkWell(
                    onTap: () => onSelectModel(e),
                    child: Container(
                      height: 36,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: isSel ? Colors.black.withOpacity(0.06) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Text(e, style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
                          if (isSel) const Icon(Icons.check, size: 16, color: Colors.black),
                        ],
                      ),
                    ),
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e', style: GoogleFonts.inter(color: Colors.red)),
            ),
          ),
        ],
      ),
    );
  }
}
