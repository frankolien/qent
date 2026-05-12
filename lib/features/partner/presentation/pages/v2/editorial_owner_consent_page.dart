import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qent/core/services/cloudinary_service.dart';
import 'package:qent/features/partner/data/models/partner_listing.dart';
import 'package:qent/features/partner/presentation/controllers/partner_v2_controller.dart';
import 'package:qent/features/partner/presentation/pages/v2/editorial_identity_page.dart';
import 'package:qent/features/partner/presentation/pages/v2/editorial_owner_page.dart'
    show
        EditorialHeader,
        EditorialStepLabel,
        EditorialField,
        EditorialContinueButton;
import 'package:qent/features/partner/presentation/pages/v2/editorial_palette.dart';

/// Step 04b — owner consent. Conditionally entered when the docs
/// step's "I'm the registered owner" toggle was off (server flips
/// `owner_consent_required = true`).
///
/// Posts the relationship + consent letter URL + the owner's phone.
/// SMS OTP to the owner is mocked in the UI ("we'll text them a
/// code") — wiring it to a real SMS provider is a follow-up.
class EditorialOwnerConsentPage extends ConsumerStatefulWidget {
  const EditorialOwnerConsentPage({super.key});

  @override
  ConsumerState<EditorialOwnerConsentPage> createState() =>
      _EditorialOwnerConsentPageState();
}

class _EditorialOwnerConsentPageState
    extends ConsumerState<EditorialOwnerConsentPage> {
  final _formKey = GlobalKey<FormState>();
  final _ownerPhoneCtrl = TextEditingController();
  final _ownerNinCtrl = TextEditingController();

  String _relationship = 'family';
  String? _consentLetterLocalPath;
  String? _consentLetterUrl;
  bool _uploading = false;
  bool _submitting = false;
  bool _hydrated = false;
  String? _listingId;

  @override
  void dispose() {
    _ownerPhoneCtrl.dispose();
    _ownerNinCtrl.dispose();
    super.dispose();
  }

  void _hydrate(PartnerListing? l) {
    if (_hydrated || l == null) return;
    _hydrated = true;
    _listingId = l.id;
    if (l.ownerRelationship != null) _relationship = l.ownerRelationship!;
    if (l.ownerConsentPhone != null) _ownerPhoneCtrl.text = l.ownerConsentPhone!;
    if (l.ownerNin != null) _ownerNinCtrl.text = l.ownerNin!;
    if (l.ownerConsentLetterUrl != null) {
      _consentLetterUrl = l.ownerConsentLetterUrl;
    }
    setState(() {});
  }

  Future<void> _pickConsentLetter() async {
    if (_uploading) return;
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null) return;
    if (!mounted) return;
    setState(() {
      _consentLetterLocalPath = picked.path;
      _uploading = true;
    });
    try {
      final url = await CloudinaryService().uploadImage(
        imageFile: File(picked.path),
        folder: 'qent/partners/consent',
      );
      if (!mounted) return;
      setState(() {
        _consentLetterUrl = url;
        _uploading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload failed — tap to retry')),
      );
    }
  }

  Future<void> _onContinue() async {
    if (_submitting) return;
    if (_uploading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hang on — letter still uploading')),
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_consentLetterUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload the consent letter to continue')),
      );
      return;
    }
    if (_listingId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listing not loaded yet')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(partnerV2ControllerProvider).submitOwnerConsent(
            listingId: _listingId!,
            ownerRelationship: _relationship,
            ownerConsentLetterUrl: _consentLetterUrl,
            ownerConsentPhone: _ownerPhoneCtrl.text.trim(),
            ownerNin: _ownerNinCtrl.text.trim().isEmpty
                ? null
                : _ownerNinCtrl.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const EditorialIdentityPage()),
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
              const EditorialHeader(stepIndex: 4, totalSteps: 6),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const EditorialStepLabel('STEP 04 · OWNER CONSENT'),
                      const SizedBox(height: 18),
                      _buildTitle(),
                      const SizedBox(height: 12),
                      Text(
                        "Loop the registered owner in — it protects everyone.",
                        style: GoogleFonts.roboto(
                          color: EditorialPalette.textSecondary,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildRelationshipTabs(),
                      const SizedBox(height: 22),
                      EditorialField(
                        label: "OWNER'S PHONE",
                        controller: _ownerPhoneCtrl,
                        keyboardType: TextInputType.phone,
                        prefix: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            '🇳🇬 +234',
                            style: GoogleFonts.roboto(
                              color: EditorialPalette.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().length < 7)
                            ? "Enter the owner's phone number"
                            : null,
                      ),
                      const SizedBox(height: 18),
                      EditorialField(
                        label: "OWNER'S NIN (OPTIONAL)",
                        controller: _ownerNinCtrl,
                        keyboardType: TextInputType.number,
                        hint: '11-digit NIN',
                      ),
                      const SizedBox(height: 22),
                      _buildConsentLetterSlot(),
                      const SizedBox(height: 16),
                      _buildOtpNote(),
                    ],
                  ),
                ),
              ),
              EditorialContinueButton(
                label: 'Send for owner approval',
                onPressed: _onContinue,
                submitting: _submitting,
                enabled: _consentLetterUrl != null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      'Whose ride\nis it really?',
      style: GoogleFonts.roboto(
        color: EditorialPalette.textPrimary,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.1,
        letterSpacing: -0.6,
      ),
    );
  }

  Widget _buildRelationshipTabs() {
    Widget tab(String value, String label) {
      final active = _relationship == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _relationship = value),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: active ? EditorialPalette.textPrimary : Colors.transparent,
              borderRadius: BorderRadius.circular(22),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: GoogleFonts.roboto(
                color: active ? Colors.white : EditorialPalette.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RELATIONSHIP',
          style: GoogleFonts.roboto(
            color: EditorialPalette.textMuted,
            fontSize: 10,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: EditorialPalette.fieldBorder),
          ),
          child: Row(
            children: [
              tab('family', 'Family'),
              tab('company', 'Company'),
              tab('other', 'Other'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConsentLetterSlot() {
    final done = _consentLetterUrl != null && !_uploading;
    return GestureDetector(
      onTap: _pickConsentLetter,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: done
                ? EditorialPalette.successAccent.withValues(alpha: 0.45)
                : EditorialPalette.fieldBorder,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: done ? 36 : 52,
              height: done ? 36 : 52,
              decoration: BoxDecoration(
                color: done
                    ? EditorialPalette.successFill
                    : EditorialPalette.fieldFill,
                borderRadius: BorderRadius.circular(done ? 10 : 12),
              ),
              child: Icon(
                Icons.article_outlined,
                color: done
                    ? EditorialPalette.successAccent
                    : EditorialPalette.textPrimary,
                size: done ? 18 : 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Signed consent letter',
                    style: GoogleFonts.roboto(
                      color: EditorialPalette.textPrimary,
                      fontSize: done ? 14.5 : 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (!done) ...[
                    const SizedBox(height: 3),
                    Text(
                      _uploading
                          ? 'Uploading…'
                          : 'PDF or image · sample on request',
                      style: GoogleFonts.roboto(
                        color: EditorialPalette.textSecondary,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (done)
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Uploaded'),
                  SizedBox(width: 6),
                  Icon(Icons.check_circle,
                      color: EditorialPalette.successAccent, size: 20),
                ],
              )
            else if (_uploading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: EditorialPalette.textSecondary,
                ),
              )
            else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: EditorialPalette.fieldFill,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Upload',
                  style: GoogleFonts.roboto(
                    color: EditorialPalette.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (_consentLetterLocalPath != null && _uploading)
              const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpNote() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EditorialPalette.fieldBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.sms_outlined,
              size: 16, color: EditorialPalette.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "We'll text the owner a 6-digit code. They approve, you continue.",
              style: GoogleFonts.roboto(
                color: EditorialPalette.textSecondary,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
