import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qent/features/partner/data/models/partner_listing.dart';
import 'package:qent/features/partner/presentation/controllers/partner_v2_controller.dart';
import 'package:qent/features/partner/presentation/pages/v2/editorial_owner_page.dart'
    show
        EditorialHeader,
        EditorialStepLabel,
        EditorialField,
        EditorialContinueButton;
import 'package:qent/features/partner/presentation/pages/v2/editorial_palette.dart';
import 'package:qent/features/partner/presentation/pages/v2/editorial_photos_page.dart';

/// Step 02 — "What are you listing?" Tier-aware brand grid + model /
/// year / color / plate fields. Posts to `/api/partner/listings` and
/// pushes Photos on Continue.
class EditorialVehiclePage extends ConsumerStatefulWidget {
  const EditorialVehiclePage({super.key});

  @override
  ConsumerState<EditorialVehiclePage> createState() =>
      _EditorialVehiclePageState();
}

class _EditorialVehiclePageState extends ConsumerState<EditorialVehiclePage> {
  final _formKey = GlobalKey<FormState>();
  final _modelCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();

  String _tier = 'luxury';
  String? _brand;
  bool _hydrated = false;
  bool _submitting = false;

  static const _regularBrands = <String>[
    'Toyota', 'Honda', 'Hyundai', 'Kia',
    'Nissan', 'Mazda', 'Volkswagen', 'Ford',
    'Chevrolet', 'Peugeot', 'Suzuki', 'Mitsubishi',
  ];
  static const _luxuryBrands = <String>[
    'Mercedes-Benz', 'BMW', 'Audi', 'Lexus',
    'Land Rover', 'Porsche', 'Jaguar', 'Tesla',
  ];
  static const _exoticBrands = <String>[
    'Bentley', 'Rolls-Royce', 'Maybach', 'Lamborghini',
    'Ferrari', 'Porsche', 'Aston Martin', 'McLaren',
  ];

  // Brand → slug in the filippofilip95/car-logos-dataset repo. The
  // logo image is then served from
  //   raw.githubusercontent.com/.../logos/optimized/<slug>.png
  // Failures fall back to a monogram circle — see `_BrandLogo`.
  static const _brandSlug = <String, String>{
    'Toyota': 'toyota',
    'Honda': 'honda',
    'Hyundai': 'hyundai',
    'Kia': 'kia',
    'Nissan': 'nissan',
    'Mazda': 'mazda',
    'Volkswagen': 'volkswagen',
    'Ford': 'ford',
    'Chevrolet': 'chevrolet',
    'Peugeot': 'peugeot',
    'Suzuki': 'suzuki',
    'Mitsubishi': 'mitsubishi',
    'Mercedes-Benz': 'mercedes-benz',
    'BMW': 'bmw',
    'Audi': 'audi',
    'Lexus': 'lexus',
    'Land Rover': 'land-rover',
    'Porsche': 'porsche',
    'Jaguar': 'jaguar',
    'Tesla': 'tesla',
    'Bentley': 'bentley',
    'Rolls-Royce': 'rolls-royce',
    'Maybach': 'maybach',
    'Lamborghini': 'lamborghini',
    'Ferrari': 'ferrari',
    'Aston Martin': 'aston-martin',
    'McLaren': 'mclaren',
  };

  List<String> get _brandsForTier => switch (_tier) {
        'regular' => _regularBrands,
        'exotic' => _exoticBrands,
        _ => _luxuryBrands,
      };

  @override
  void dispose() {
    _modelCtrl.dispose();
    _yearCtrl.dispose();
    _colorCtrl.dispose();
    _plateCtrl.dispose();
    super.dispose();
  }

  /// Pre-fill form fields from a server-side draft (the host hit Back
  /// or the app was killed). Idempotent — only runs once per mount so
  /// later cache invalidations don't clobber in-progress edits.
  void _hydrate(PartnerListing? l) {
    if (_hydrated || l == null) return;
    _hydrated = true;
    _tier = l.tier;
    _brand = l.brand.isEmpty ? null : l.brand;
    _modelCtrl.text = l.model;
    _yearCtrl.text = l.year?.toString() ?? '';
    _colorCtrl.text = l.color ?? '';
    _plateCtrl.text = l.plateNumber;
    setState(() {});
  }

  Future<void> _onContinue() async {
    if (_submitting) return;
    if (_brand == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a brand')),
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      final yearText = _yearCtrl.text.trim();
      final year = yearText.isEmpty ? null : int.tryParse(yearText);
      await ref.read(partnerV2ControllerProvider).saveVehicleStep(
            tier: _tier,
            brand: _brand!,
            model: _modelCtrl.text.trim(),
            year: year,
            color: _colorCtrl.text.trim().isEmpty
                ? null
                : _colorCtrl.text.trim(),
            plateNumber: _plateCtrl.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const EditorialPhotosPage()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Resume the form from the server-side draft on first paint, and
    // again whenever another screen invalidates the cache.
    ref.listen<AsyncValue<PartnerListing?>>(partnerDraftListingProvider,
        (_, next) {
      next.whenData(_hydrate);
    });
    ref.watch(partnerDraftListingProvider).whenData(_hydrate);

    return Scaffold(
      backgroundColor: EditorialPalette.background,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const EditorialHeader(stepIndex: 2, totalSteps: 6),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const EditorialStepLabel('STEP 02 · THE CAR'),
                      const SizedBox(height: 18),
                      _buildTitle(),
                      const SizedBox(height: 28),
                      _buildTierTabs(),
                      const SizedBox(height: 22),
                      _buildBrandGrid(),
                      const SizedBox(height: 28),
                      EditorialField(
                        label: 'MODEL',
                        controller: _modelCtrl,
                        hint: 'e.g. Phantom Series II',
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter the model'
                            : null,
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: EditorialField(
                              label: 'YEAR',
                              controller: _yearCtrl,
                              hint: '2024',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: EditorialField(
                              label: 'COLOR',
                              controller: _colorCtrl,
                              hint: 'Obsidian Black',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      EditorialField(
                        label: 'PLATE NUMBER',
                        controller: _plateCtrl,
                        textCapitalization: TextCapitalization.characters,
                        hint: 'LAG-001-AB',
                        validator: (v) => (v == null || v.trim().length < 4)
                            ? 'Enter a valid plate number'
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              EditorialContinueButton(
                label: 'Next: photos',
                onPressed: _onContinue,
                submitting: _submitting,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What are you',
          style: GoogleFonts.roboto(
            color: EditorialPalette.textSecondary,
            fontSize: 22,
            fontWeight: FontWeight.w500,
            height: 1.1,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'listing?',
          style: GoogleFonts.roboto(
            color: EditorialPalette.textPrimary,
            fontSize: 38,
            fontWeight: FontWeight.w700,
          
            height: 1.05,
            letterSpacing: -1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildTierTabs() {
    Widget tab(String value, String label) {
      final active = _tier == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() {
            _tier = value;
            if (_brand != null && !_brandsForTier.contains(_brand)) {
              _brand = null;
            }
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: active
                  ? EditorialPalette.textPrimary
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(22),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: GoogleFonts.roboto(
                color: active
                    ? Colors.white
                    : EditorialPalette.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: EditorialPalette.fieldBorder),
      ),
      child: Row(
        children: [
          tab('regular', 'Regular'),
          tab('luxury', 'Luxury'),
          tab('exotic', 'Exotic'),
        ],
      ),
    );
  }

  Widget _buildBrandGrid() {
    final brands = _brandsForTier;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BRAND',
          style: GoogleFonts.roboto(
            color: EditorialPalette.textMuted,
            fontSize: 10,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 3.0,
          children: brands.map(_buildBrandTile).toList(),
        ),
      ],
    );
  }

  Widget _buildBrandTile(String brand) {
    final active = brand == _brand;
    return GestureDetector(
      onTap: () => setState(() => _brand = brand),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active
                ? EditorialPalette.textPrimary
                : EditorialPalette.fieldBorder,
            width: active ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            _BrandLogo(brand: brand),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                brand,
                style: GoogleFonts.roboto(
                  color: EditorialPalette.textPrimary,
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  letterSpacing: -0.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Square logo chip backed by Clearbit's free CDN. Falls back to a
/// Brand mark loaded from filippofilip95/car-logos-dataset. Falls
/// back to a monogram (first letter) when the image fails — covers
/// offline mode and any brand not in the dataset.
class _BrandLogo extends StatelessWidget {
  final String brand;
  const _BrandLogo({required this.brand});

  @override
  Widget build(BuildContext context) {
    final slug = _EditorialVehiclePageState._brandSlug[brand];
    return SizedBox(
      width: 32,
      height: 32,
      child: slug == null
          ? _fallback()
          : Image.network(
              'https://raw.githubusercontent.com/filippofilip95/car-logos-dataset/master/logos/optimized/$slug.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _fallback(),
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : _fallback(),
            ),
    );
  }

  Widget _fallback() {
    return Center(
      child: Text(
        brand.isNotEmpty ? brand[0] : '',
        style: GoogleFonts.roboto(
          color: EditorialPalette.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
