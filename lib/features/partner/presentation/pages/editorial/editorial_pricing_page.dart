import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qent/core/utils/friendly_error.dart';
import 'package:qent/features/partner/data/models/partner_listing.dart';
import 'package:qent/features/partner/presentation/controllers/partner_onboarding_controller.dart';
import 'package:qent/features/partner/presentation/pages/editorial/editorial_owner_page.dart'
    show EditorialHeader, EditorialStepLabel, EditorialField, EditorialContinueButton;
import 'package:qent/features/partner/presentation/pages/editorial/editorial_palette.dart';
import 'package:qent/features/partner/presentation/pages/editorial/editorial_success_page.dart';

class EditorialPricingPage extends ConsumerStatefulWidget {
  const EditorialPricingPage({super.key});

  @override
  ConsumerState<EditorialPricingPage> createState() => _EditorialPricingPageState();
}

class _EditorialPricingPageState extends ConsumerState<EditorialPricingPage> {
  final _formKey = GlobalKey<FormState>();
  final _priceCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String? _listingId;
  bool _hydrated = false;
  bool _submitting = false;

  void _hydrate(PartnerListing? draft) {
    if (_hydrated || draft == null) return;
    _hydrated = true;
    _listingId = draft.id;
    if (draft.pricePerDay != null) {
      _priceCtrl.text = draft.pricePerDay!.toStringAsFixed(0);
    }
    if (draft.location != null) _locationCtrl.text = draft.location!;
    if (draft.description != null) _descCtrl.text = draft.description!;
  }

  Future<void> _onContinue() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_listingId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listing not loaded yet — go back and try again')),
      );
      return;
    }

    final price = double.tryParse(_priceCtrl.text.trim());
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid daily price')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(partnerOnboardingControllerProvider).saveListingPricing(
            listingId: _listingId!,
            pricePerDay: price,
            location: _locationCtrl.text.trim(),
            description: _descCtrl.text.trim().isEmpty
                ? null
                : _descCtrl.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const EditorialSuccessPage()),
      );
    } catch (e, st) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e, tag: 'Partner/pricing', stack: st))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _locationCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<PartnerListing?>>(
      partnerDraftListingProvider,
      (_, next) => next.whenData(_hydrate),
    );
    ref.watch(partnerDraftListingProvider).whenData(_hydrate);

    return Scaffold(
      backgroundColor: EditorialPalette.background,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const EditorialHeader(stepIndex: 5, totalSteps: 5),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const EditorialStepLabel('STEP 05 · YOUR PRICE'),
                      const SizedBox(height: 18),
                      Text(
                        'Set your daily price\nand where the car is.',
                        style: GoogleFonts.roboto(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          color: EditorialPalette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 28),
                      EditorialField(
                        label: 'PRICE PER DAY (₦)',
                        controller: _priceCtrl,
                        hint: 'e.g. 45000',
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final s = v?.trim() ?? '';
                          if (s.isEmpty) return 'Enter your daily price';
                          final n = double.tryParse(s);
                          if (n == null || n <= 0) return 'Enter a valid amount';
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      EditorialField(
                        label: 'LOCATION',
                        controller: _locationCtrl,
                        hint: 'e.g. Lekki Phase 1, Lagos',
                        validator: (v) => (v == null || v.trim().length < 2)
                            ? 'Enter a pickup location'
                            : null,
                      ),
                      const SizedBox(height: 18),
                      EditorialField(
                        label: 'DESCRIPTION (OPTIONAL)',
                        controller: _descCtrl,
                        hint: 'A short pitch renters will see',
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: EditorialContinueButton(
                  label: _submitting ? 'Saving…' : 'Continue',
                  onPressed: _onContinue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
