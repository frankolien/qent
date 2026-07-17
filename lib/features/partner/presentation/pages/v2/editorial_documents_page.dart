import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qent/core/services/cloudinary_service.dart';
import 'package:qent/core/utils/friendly_error.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart';
import 'package:qent/features/kyc/presentation/pages/kyc_launcher_page.dart';
import 'package:qent/features/partner/data/datasources/partner_v2_datasource.dart';
import 'package:qent/features/partner/data/models/partner_listing.dart';
import 'package:qent/features/partner/data/models/partner_profile.dart';
import 'package:qent/features/partner/presentation/controllers/partner_v2_controller.dart';
import 'package:qent/features/partner/presentation/pages/v2/editorial_owner_consent_page.dart';
import 'package:qent/features/partner/presentation/pages/v2/editorial_owner_page.dart'
    show EditorialHeader, EditorialStepLabel, EditorialContinueButton;
import 'package:qent/features/partner/presentation/pages/v2/editorial_palette.dart';
import 'package:qent/features/partner/presentation/pages/v2/editorial_pricing_page.dart';

/// Step 04 — vehicle documents + Sumsub identity gate.
///
/// Driver identity is now handled out-of-band by Sumsub (the renter
/// KYC launcher); this page only collects the two vehicle papers
/// (C of R + insurance) and the host's "I'm the registered owner"
/// declaration. Continue is gated on `kyc_tier >= 1` so a host that
/// hasn't completed Sumsub gets an inline launcher card instead.
class EditorialDocumentsPage extends ConsumerStatefulWidget {
  const EditorialDocumentsPage({super.key});

  @override
  ConsumerState<EditorialDocumentsPage> createState() =>
      _EditorialDocumentsPageState();
}

enum _DocKind { vehicleRegistration, insurance }

class _DocSlot {
  final _DocKind kind;
  final String title;
  final String subtitle;
  String? localPath;
  String? remoteUrl;
  bool uploading;
  _DocSlot({required this.kind, required this.title, required this.subtitle})
      : uploading = false;

  bool get done => remoteUrl != null && remoteUrl!.isNotEmpty;
}

class _EditorialDocumentsPageState
    extends ConsumerState<EditorialDocumentsPage> {
  final _slots = <_DocSlot>[
    _DocSlot(
      kind: _DocKind.vehicleRegistration,
      title: 'Vehicle registration',
      subtitle: 'C of R · we cross-check the plate',
    ),
    _DocSlot(
      kind: _DocKind.insurance,
      title: 'Insurance certificate',
      subtitle: 'Comprehensive · still valid',
    ),
  ];

  final _policyCtrl = TextEditingController();
  bool _isRegisteredOwner = true;
  String? _listingId;
  bool _hydrated = false;
  bool _submitting = false;

  @override
  void dispose() {
    _policyCtrl.dispose();
    super.dispose();
  }

  /// Pre-fill from anything the host already saved server-side.
  void _hydrate({PartnerProfile? profile, PartnerListing? listing}) {
    if (_hydrated) return;
    if (listing == null) return; // need a listing id to submit anything
    _hydrated = true;
    _listingId = listing.id;
    // profile is intentionally unused now — DL fields aren't collected
    // here anymore.
    if (listing.vehicleRegistrationUrl != null) {
      _slots
          .firstWhere((s) => s.kind == _DocKind.vehicleRegistration)
          .remoteUrl = listing.vehicleRegistrationUrl;
    }
    if (listing.insuranceCertificateUrl != null) {
      _slots
          .firstWhere((s) => s.kind == _DocKind.insurance)
          .remoteUrl = listing.insuranceCertificateUrl;
    }
    if (listing.insurancePolicyNumber != null) {
      _policyCtrl.text = listing.insurancePolicyNumber!;
    }
    if (listing.ownerMatch != null) {
      _isRegisteredOwner = listing.ownerMatch!;
    }
    setState(() {});
  }

  bool get _allUploaded => _slots.every((s) => s.done);
  bool get _anyUploading => _slots.any((s) => s.uploading);

  Future<void> _pickFor(_DocSlot slot) async {
    if (slot.uploading) return;
    final picker = ImagePicker();
    // Docs must stay readable, so keep quality high but cap the long edge.
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      imageQuality: 80,
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(() {
      slot.localPath = picked.path;
      slot.uploading = true;
    });
    try {
      final url = await CloudinaryService().uploadImage(
        imageFile: File(picked.path),
        folder: 'qent/partners/docs',
      );
      if (!mounted) return;
      setState(() {
        slot.remoteUrl = url;
        slot.uploading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => slot.uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload failed — tap to retry')),
      );
    }
  }

  /// Push the renter-style KYC launcher. On return, refreshProfile()
  /// has already run inside the launcher; the watcher in build() will
  /// rebuild with the new tier.
  Future<void> _startIdentityVerification() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const KycLauncherPage()),
    );
  }

  Future<void> _onContinue() async {
    if (_submitting) return;
    if (_anyUploading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hang on — uploads finishing')),
      );
      return;
    }
    if (!_allUploaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload both documents to continue')),
      );
      return;
    }
    if (_listingId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Listing not loaded yet — go back and try again')),
      );
      return;
    }
    final tier = ref.read(authControllerProvider).user?.kycTier ?? 0;
    if (tier < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verify your identity first')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final reg =
          _slots.firstWhere((s) => s.kind == _DocKind.vehicleRegistration);
      final ins = _slots.firstWhere((s) => s.kind == _DocKind.insurance);
      final policy = _policyCtrl.text.trim();
      final out = await ref.read(partnerV2ControllerProvider).submitListingDocs(
            listingId: _listingId!,
            vehicleRegistrationUrl: reg.remoteUrl,
            insuranceCertificateUrl: ins.remoteUrl,
            insurancePolicyNumber: policy.isEmpty ? null : policy,
            isRegisteredOwner: _isRegisteredOwner,
          );
      if (!mounted) return;
      // Plate endpoint can't expose registered owner; the toggle
      // alone drives the 04b branch.
      if (out.ownerConsentRequired) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const EditorialOwnerConsentPage()),
        );
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const EditorialPricingPage()),
        );
      }
    } on PartnerDocsException catch (e) {
      if (!mounted) return;
      if (e.isIdentityRequired) {
        await _startIdentityVerification();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e, st) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e, tag: 'Partner/docs', stack: st))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pull both profile + draft listing so we can hydrate from
    // whatever the host already saved in earlier sessions.
    final profileAsync = ref.watch(partnerProfileProvider);
    final listingAsync = ref.watch(partnerDraftListingProvider);
    if (profileAsync is AsyncData<PartnerProfile?> &&
        listingAsync is AsyncData<PartnerListing?>) {
      _hydrate(profile: profileAsync.value, listing: listingAsync.value);
    }

    return Scaffold(
      backgroundColor: EditorialPalette.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const EditorialHeader(stepIndex: 4, totalSteps: 5),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const EditorialStepLabel('STEP 04 · DOCUMENTS'),
                    const SizedBox(height: 18),
                    _buildTitle(),
                    const SizedBox(height: 12),
                    Text(
                      'Stored encrypted. Visible only to QENT compliance.',
                      style: GoogleFonts.roboto(
                        color: EditorialPalette.textSecondary,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _buildIdentityCard(),
                    const SizedBox(height: 16),
                    ..._slots.map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child:
                              _DocCard(slot: s, onTap: () => _pickFor(s)),
                        )),
                    const SizedBox(height: 8),
                    _buildPolicyField(),
                    const SizedBox(height: 16),
                    _buildOwnerToggle(),
                    const SizedBox(height: 22),
                    _buildEncryptedCard(),
                  ],
                ),
              ),
            ),
            EditorialContinueButton(
              label: 'Continue',
              onPressed: _onContinue,
              enabled: _allUploaded &&
                  (ref.watch(authControllerProvider).user?.kycTier ?? 0) >= 1,
              submitting: _submitting,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      'Identity +\ntwo papers.',
      style: GoogleFonts.roboto(
        color: EditorialPalette.textPrimary,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.1,
        letterSpacing: -0.6,
      ),
    );
  }

  /// Sumsub identity gate. When `kyc_tier == 0` the card pushes the
  /// renter KYC launcher; once the webhook flips the tier, the card
  /// switches to a green "Identity verified" state. The backend
  /// gates /partner/listings/:id/docs on the same flag, so this is
  /// just a UX surface.
  Widget _buildIdentityCard() {
    final tier = ref.watch(authControllerProvider).user?.kycTier ?? 0;
    final verified = tier >= 1;
    return GestureDetector(
      onTap: verified ? null : _startIdentityVerification,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: verified
                ? EditorialPalette.successAccent.withValues(alpha: 0.5)
                : EditorialPalette.fieldBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: verified
                    ? EditorialPalette.successFill
                    : EditorialPalette.fieldFill,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                verified ? Icons.verified_rounded : Icons.badge_outlined,
                color: verified
                    ? EditorialPalette.successAccent
                    : EditorialPalette.textPrimary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    verified ? 'Identity verified' : 'Verify your identity',
                    style: GoogleFonts.roboto(
                      color: EditorialPalette.textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    verified
                        ? 'Sumsub confirmed your ID. You\'re cleared to host.'
                        : 'Quick selfie + ID scan via Sumsub. ~60 seconds.',
                    style: GoogleFonts.roboto(
                      color: EditorialPalette.textSecondary,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (verified)
              const Icon(Icons.check_circle,
                  color: EditorialPalette.successAccent, size: 20)
            else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: EditorialPalette.textPrimary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Start',
                  style: GoogleFonts.roboto(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicyField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'INSURANCE POLICY NUMBER',
          style: GoogleFonts.roboto(
            color: EditorialPalette.textMuted,
            fontSize: 10,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _policyCtrl,
          textCapitalization: TextCapitalization.characters,
          style: GoogleFonts.roboto(
            color: EditorialPalette.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'AAO/24/4/00000/20',
            hintStyle: GoogleFonts.roboto(
              color: EditorialPalette.textMuted,
              fontSize: 13,
            ),
            isDense: true,
            filled: true,
            fillColor: EditorialPalette.fieldFill,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: EditorialPalette.fieldBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: EditorialPalette.fieldBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: EditorialPalette.fieldBorderFocused, width: 1.4),
            ),
          ),
        ),
      ],
    );
  }

  /// "I'm the registered owner" toggle. When `false` the server flips
  /// `owner_consent_required = true` and the next push lands on 04b
  /// instead of Identity.
  Widget _buildOwnerToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: EditorialPalette.fieldBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user_outlined,
              size: 18, color: EditorialPalette.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "I'm the registered owner",
                  style: GoogleFonts.roboto(
                    color: EditorialPalette.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Turn off if the C of R is in someone else\'s name',
                  style: GoogleFonts.roboto(
                    color: EditorialPalette.textSecondary,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _isRegisteredOwner,
            activeThumbColor: EditorialPalette.successAccent,
            onChanged: (v) => setState(() => _isRegisteredOwner = v),
          ),
        ],
      ),
    );
  }

  Widget _buildEncryptedCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EditorialPalette.fieldFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EditorialPalette.fieldBorder, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.lock_outline,
                color: EditorialPalette.textPrimary, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'End-to-end encrypted',
                  style: GoogleFonts.roboto(
                    color: EditorialPalette.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.roboto(
                      color: EditorialPalette.textSecondary,
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                    children: [
                      const TextSpan(
                          text:
                              'Documents are deleted from our review queue after verification. Read our '),
                      TextSpan(
                        text: 'data policy',
                        style: GoogleFonts.roboto(
                          color: EditorialPalette.textPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Single document slot card — three visual states:
///   idle      : white card, grey icon chip, "Upload" pill on the right
///   uploading : white card, grey icon chip, dark spinner on the right
///   done      : white card, green-tinted border + icon, "Verified" + check
class _DocCard extends StatelessWidget {
  final _DocSlot slot;
  final VoidCallback onTap;
  const _DocCard({required this.slot, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final done = slot.done;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: done
            ? const EdgeInsets.symmetric(horizontal: 14, vertical: 12)
            : const EdgeInsets.all(14),
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
        child: done ? _buildDone() : _buildPending(),
      ),
    );
  }

  Widget _buildDone() {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: EditorialPalette.successFill,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.description_outlined,
              color: EditorialPalette.successAccent, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            slot.title,
            style: GoogleFonts.roboto(
              color: EditorialPalette.textPrimary,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),
        Text(
          'Uploaded',
          style: GoogleFonts.roboto(
            color: EditorialPalette.successAccent,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.check_circle,
            color: EditorialPalette.successAccent, size: 20),
      ],
    );
  }

  Widget _buildPending() {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: EditorialPalette.fieldFill,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.description_outlined,
              color: EditorialPalette.textPrimary, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                slot.title,
                style: GoogleFonts.roboto(
                  color: EditorialPalette.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                slot.uploading ? 'Uploading…' : slot.subtitle,
                style: GoogleFonts.roboto(
                  color: EditorialPalette.textSecondary,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        slot.uploading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: EditorialPalette.textSecondary,
                ),
              )
            : Container(
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
      ],
    );
  }
}
