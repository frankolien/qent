import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qent/core/services/cloudinary_service.dart';
import 'package:qent/core/theme/app_theme.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart';
import 'package:qent/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:qent/features/partner/presentation/providers/partner_providers.dart';

class AddListingPage extends ConsumerStatefulWidget {
  const AddListingPage({super.key});

  @override
  ConsumerState<AddListingPage> createState() => _AddListingPageState();
}

class _AddListingPageState extends ConsumerState<AddListingPage> {
  final _formKey = GlobalKey<FormState>();
  final _registrationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  final _yearController = TextEditingController(text: '2024');
  final _seatsController = TextEditingController(text: '5');

  String? _selectedBrand;
  String? _selectedLuxuryBrand;
  String? _selectedModel;
  String? _selectedColor = 'Black';
  bool _showBrandSelection = true;
  bool _isSubmitting = false;
  final List<String> _localImagePaths = [];

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

  @override
  void dispose() {
    _registrationController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _yearController.dispose();
    _seatsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: context.bgSecondary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.arrow_back_ios_new, size: 16, color: context.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Add New Listing',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Form content
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: context.bgPrimary,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBrandModelSection(),
                        const SizedBox(height: 28),
                        _buildImageUpload(),
                        const SizedBox(height: 28),
                        Row(
                          children: [
                            Expanded(child: _buildField('Year', _yearController, TextInputType.number)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildField('Seats', _seatsController, TextInputType.number)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildField('Price/day (\$)', _priceController, TextInputType.number)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildField('Plate Number', _registrationController, TextInputType.text)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildField('Location', _locationController, TextInputType.text, hint: 'e.g. Lagos, Abuja'),
                        const SizedBox(height: 24),
                        _buildColorsSection(),
                        const SizedBox(height: 24),
                        _buildDescriptionField(),
                        const SizedBox(height: 32),
                        _buildSubmitButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, TextInputType type, {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.textSecondary),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: type,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[350], fontSize: 14),
            filled: true,
            fillColor: context.inputBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.inputBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.accent, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: context.textPrimary),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
      ],
    );
  }

  Widget _buildBrandModelSection() {
    final brand = _selectedBrand ?? _selectedLuxuryBrand;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vehicle',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.textSecondary),
        ),
        const SizedBox(height: 8),
        // Toggle
        Container(
          decoration: BoxDecoration(
            color: context.bgSecondary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _buildToggle('Brand', _showBrandSelection, () => setState(() => _showBrandSelection = true)),
              _buildToggle('Model', !_showBrandSelection, () {
                if (brand != null) setState(() => _showBrandSelection = false);
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_showBrandSelection)
          _buildBrandsList()
        else if (brand != null)
          _buildModelsList(brand),
        if (brand != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: context.inputBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(
                  brand,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary),
                ),
                if (_selectedModel != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('/', style: TextStyle(color: context.textSecondary)),
                  ),
                  Text(
                    _selectedModel!,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary),
                  ),
                ],
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() {
                    _selectedBrand = null;
                    _selectedLuxuryBrand = null;
                    _selectedModel = null;
                    _showBrandSelection = true;
                  }),
                  child: Icon(Icons.close, size: 18, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildToggle(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: active
                ? (context.isDark ? context.accent : const Color(0xFF1A1A1A))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active
                  ? (context.isDark ? Colors.black : Colors.white)
                  : context.textSecondary,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandsList() {
    final regular = ref.watch(regularBrandsProvider);
    final luxury = ref.watch(luxuryBrandsProvider);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.bgSecondary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Regular', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.textSecondary)),
                const SizedBox(height: 6),
                ...regular.map((b) => _brandTile(b, () {
                  setState(() {
                    _selectedBrand = b;
                    _selectedLuxuryBrand = null;
                    _selectedModel = null;
                    _showBrandSelection = false;
                  });
                })),
              ],
            ),
          ),
          Container(width: 1, height: 220, color: context.borderColor),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Luxury', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.textSecondary)),
                  const SizedBox(height: 6),
                  ...luxury.map((b) => _brandTile(b, () {
                    setState(() {
                      _selectedLuxuryBrand = b;
                      _selectedBrand = null;
                      _selectedModel = null;
                      _showBrandSelection = false;
                    });
                  })),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _brandTile(String name, VoidCallback onTap) {
    final isSelected = name == _selectedBrand || name == _selectedLuxuryBrand;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1A1A1A).withValues(alpha: 0.06) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          name,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: context.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildModelsList(String brand) {
    final models = ref.watch(modelsProvider(brand));
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.bgSecondary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Models for $brand', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.textSecondary)),
          const SizedBox(height: 6),
          if (models.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No models available', style: TextStyle(color: context.textSecondary, fontSize: 13)),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: models.map((m) {
                final isSelected = m == _selectedModel;
                return GestureDetector(
                  onTap: () => setState(() => _selectedModel = m),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (context.isDark ? context.accent : const Color(0xFF1A1A1A))
                          : context.bgPrimary,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? (context.isDark ? context.accent : const Color(0xFF1A1A1A))
                            : context.borderColor,
                      ),
                    ),
                    child: Text(
                      m,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? (context.isDark ? Colors.black : Colors.white)
                            : context.textPrimary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildImageUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Photos',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.textSecondary),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 90,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              // Add button
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: context.bgSecondary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined, size: 22, color: Colors.grey[400]),
                      const SizedBox(height: 4),
                      Text(
                        'Add',
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
              ),
              // Uploaded images
              ..._localImagePaths.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          File(entry.value),
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => setState(() => _localImagePaths.removeAt(entry.key)),
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1A1A1A),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        if (_localImagePaths.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${_localImagePaths.length} photo${_localImagePaths.length == 1 ? '' : 's'} selected',
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
          ),
      ],
    );
  }

  Widget _buildColorsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Color',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.textSecondary),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _colors.map((c) {
              final String name = c['name'] as String;
              final Color color = c['color'] as Color;
              final bool sel = _selectedColor == name;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedColor = name),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          border: sel
                              ? Border.all(color: const Color(0xFF1A1A1A), width: 2.5)
                              : Border.all(color: Colors.grey[300]!, width: 1),
                        ),
                        child: sel
                            ? Icon(
                                Icons.check,
                                color: (color == Colors.white || color == const Color(0xFFBDBDBD) || color == const Color(0xFFC0C0C0))
                                    ? const Color(0xFF1A1A1A)
                                    : Colors.white,
                                size: 16,
                              )
                            : null,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                          color: sel ? context.textPrimary : context.textSecondary,
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

  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.textSecondary),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _descriptionController,
          maxLines: 4,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Describe your vehicle...',
            hintStyle: TextStyle(color: Colors.grey[350], fontSize: 14),
            filled: true,
            fillColor: context.inputBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.inputBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.accent, width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(16),
            counterStyle: TextStyle(color: context.textSecondary, fontSize: 11),
          ),
          style: TextStyle(fontSize: 14, color: context.textPrimary),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: GestureDetector(
        onTap: _isSubmitting ? null : _handleSubmit,
        child: Container(
          decoration: BoxDecoration(
            color: _isSubmitting
                ? Colors.grey[400]
                : (context.isDark ? context.accent : const Color(0xFF1A1A1A)),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: _isSubmitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  'Submit Listing',
                  style: TextStyle(
                    color: context.isDark ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, maxHeight: 1200, imageQuality: 85);
    if (picked != null) {
      setState(() => _localImagePaths.add(picked.path));
    }
  }

  Future<void> _handleSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final brand = _selectedBrand ?? _selectedLuxuryBrand;
    if (brand == null) {
      _showSnack('Please select a car brand');
      return;
    }
    if (_selectedModel == null) {
      _showSnack('Please select a car model');
      return;
    }
    if (_localImagePaths.length < 2) {
      _showSnack('Please add at least 2 photos');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Upload images to Cloudinary
      final cloudinary = CloudinaryService();
      final uploadedUrls = <String>[];

      for (final path in _localImagePaths) {
        final url = await cloudinary.uploadImage(
          imageFile: File(path),
          folder: 'qent/cars',
        );
        if (url != null) {
          uploadedUrls.add(url);
        }
      }

      if (uploadedUrls.length < 2) {
        _showSnack('Failed to upload images. Please try again.');
        setState(() => _isSubmitting = false);
        return;
      }

      // Create car via API
      final dataSource = ref.read(apiCarDataSourceProvider);
      await dataSource.createCar(
        make: brand,
        model: _selectedModel!,
        year: int.tryParse(_yearController.text.trim()) ?? 2024,
        color: _selectedColor ?? 'Black',
        plateNumber: _registrationController.text.trim(),
        description: _descriptionController.text.trim(),
        pricePerDay: double.tryParse(_priceController.text.trim()) ?? 0.0,
        location: _locationController.text.trim(),
        photos: uploadedUrls,
        seats: int.tryParse(_seatsController.text.trim()) ?? 5,
      );

      // Refresh dashboard data
      ref.invalidate(hostStatsProvider);
      ref.invalidate(hostListingsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Listing submitted for approval'),
            backgroundColor: Color(0xFF1A1A1A),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      _showSnack('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red[400]),
      );
    }
  }
}
