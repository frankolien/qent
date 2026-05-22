import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qent/core/services/cloudinary_service.dart';
import 'package:qent/core/utils/friendly_error.dart';
import 'package:qent/features/partner/data/models/partner_profile.dart';
import 'package:qent/features/partner/presentation/controllers/partner_v2_controller.dart';
import 'package:qent/features/partner/presentation/pages/v2/editorial_email_verify_page.dart';
import 'package:qent/features/partner/presentation/pages/v2/editorial_palette.dart';

/// Step 01 of the Editorial partner onboarding flow — "Tell us who's
/// behind the wheel." Cream background, serif italic emphasis, posts
/// to `/api/partner/profile` on Continue.
class EditorialOwnerPage extends ConsumerStatefulWidget {
  const EditorialOwnerPage({super.key});

  @override
  ConsumerState<EditorialOwnerPage> createState() => _EditorialOwnerPageState();
}

class _EditorialOwnerPageState extends ConsumerState<EditorialOwnerPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();

  String? _localPhotoPath;
  String? _profilePhotoUrl;
  bool _emailValid = false;
  bool _hydrated = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl.addListener(_onEmailChanged);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _licenseCtrl.dispose();
    super.dispose();
  }

  void _onEmailChanged() {
    final v = _emailCtrl.text.trim();
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
    if (ok != _emailValid) setState(() => _emailValid = ok);
  }

  /// Pre-fill the form once the server-side draft resolves. Idempotent —
  /// the `_hydrated` guard makes sure we don't clobber the user's
  /// edits after the first paint.
  void _hydrateFromProfile(PartnerProfile? p) {
    if (_hydrated || p == null) return;
    _hydrated = true;
    _nameCtrl.text = p.legalFullName;
    _emailCtrl.text = p.contractEmail;
    _phoneCtrl.text = p.phone;
    _licenseCtrl.text = p.driversLicenseNumber;
    _profilePhotoUrl = p.profilePhotoUrl;
    _onEmailChanged();
    setState(() {});
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      imageQuality: 75,
    );
    if (picked == null) return;
    setState(() => _localPhotoPath = picked.path);
    // Background upload — don't block the UI. The URL slots into
    // `_profilePhotoUrl` once Cloudinary returns and rides the next
    // `saveOwnerStep` call.
    try {
      final url = await CloudinaryService().uploadImage(
        imageFile: File(picked.path),
        folder: 'qent/partners',
      );
      if (mounted) setState(() => _profilePhotoUrl = url);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo upload failed — try again')),
        );
      }
    }
  }

  Future<void> _onContinue() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await ref.read(partnerV2ControllerProvider).saveOwnerStep(
            legalFullName: _nameCtrl.text.trim(),
            contractEmail: _emailCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            driversLicenseNumber: _licenseCtrl.text.trim(),
            profilePhotoUrl: _profilePhotoUrl,
          );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EditorialEmailVerifyPage(
            email: _emailCtrl.text.trim(),
          ),
        ),
      );
    } catch (e, st) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e, tag: 'Partner/owner', stack: st))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Hydrate once when the FutureProvider resolves, and again any
    // time the cached profile is invalidated by another screen.
    ref.listen<AsyncValue<PartnerProfile?>>(partnerProfileProvider, (_, next) {
      next.whenData(_hydrateFromProfile);
    });
    ref.watch(partnerProfileProvider).whenData(_hydrateFromProfile);

    return Scaffold(
      backgroundColor: EditorialPalette.background,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const EditorialHeader(stepIndex: 1, totalSteps: 6),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const EditorialStepLabel('STEP 01 · ABOUT YOU'),
                      const SizedBox(height: 18),
                      _buildTitle(),
                      const SizedBox(height: 12),
                      Text(
                        "We'll keep this private. It only appears on rental contracts.",
                        style: GoogleFonts.roboto(
                          color: EditorialPalette.textSecondary,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _buildPhotoPicker(),
                      const SizedBox(height: 28),
                      _buildField(
                        label: 'FULL NAME',
                        controller: _nameCtrl,
                        validator: (v) => (v == null || v.trim().length < 2)
                            ? 'Enter your full name'
                            : null,
                      ),
                      const SizedBox(height: 18),
                      _buildField(
                        label: 'EMAIL',
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        suffix: _emailValid
                            ? const Icon(Icons.check,
                                color: EditorialPalette.textPrimary, size: 20)
                            : null,
                        validator: (v) => _emailValid
                            ? null
                            : 'Enter a valid email address',
                      ),
                      const SizedBox(height: 18),
                      _buildField(
                        label: 'PHONE',
                        controller: _phoneCtrl,
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
                            ? 'Enter a valid phone number'
                            : null,
                      ),
                      const SizedBox(height: 18),
                      _buildField(
                        label: 'DRIVING LICENSE NUMBER',
                        controller: _licenseCtrl,
                        textCapitalization: TextCapitalization.characters,
                        hint: 'DL-0000-0000-0000',
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter your driving license number'
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              EditorialContinueButton(
                label: 'Continue',
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
    return Text(
      "Tell us who's\nbehind the wheel.",
      style: GoogleFonts.roboto(
        color: EditorialPalette.textPrimary,
        fontSize: 30,
        fontWeight: FontWeight.w700,
        height: 1.15,
        letterSpacing: -0.6,
      ),
    );
  }

  Widget _buildPhotoPicker() {
    final hasImage = _localPhotoPath != null;
    return InkWell(
      onTap: _pickPhoto,
      borderRadius: BorderRadius.circular(50),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          DottedCircle(
            size: 64,
            color: EditorialPalette.divider,
            child: hasImage
                ? ClipOval(
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child:
                          Image.file(File(_localPhotoPath!), fit: BoxFit.cover),
                    ),
                  )
                : const Icon(Icons.photo_camera_outlined,
                    color: EditorialPalette.textSecondary, size: 22),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasImage ? 'Change photo' : 'Add a photo',
                style: GoogleFonts.roboto(
                  color: EditorialPalette.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Optional, but builds trust',
                style: GoogleFonts.roboto(
                  color: EditorialPalette.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    Widget? prefix,
    Widget? suffix,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return EditorialField(
      label: label,
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      prefix: prefix,
      suffix: suffix,
      hint: hint,
      validator: validator,
    );
  }
}

// ─── Shared editorial widgets (used by Owner / Vehicle / Photos) ───────────

/// Top header with circular back button, "BECOME A PARTNER" title, and
/// step counter, plus a thin progress underline.
class EditorialHeader extends StatelessWidget {
  final int stepIndex;
  final int totalSteps;
  const EditorialHeader({
    super.key,
    required this.stepIndex,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    final progress = stepIndex / totalSteps;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: EditorialPalette.divider, width: 1),
                  ),
                  child: const Icon(Icons.chevron_left,
                      color: EditorialPalette.textPrimary, size: 22),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'BECOME A PARTNER',
                style: GoogleFonts.roboto(
                  color: EditorialPalette.textPrimary,
                  fontSize: 11,
                  letterSpacing: 2.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${stepIndex.toString().padLeft(2, '0')} / ${totalSteps.toString().padLeft(2, '0')}',
                style: GoogleFonts.roboto(
                  color: EditorialPalette.textSecondary,
                  fontSize: 11,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 2,
              backgroundColor: EditorialPalette.divider,
              valueColor: const AlwaysStoppedAnimation(
                  EditorialPalette.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class EditorialStepLabel extends StatelessWidget {
  final String text;
  const EditorialStepLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.roboto(
        color: EditorialPalette.textMuted,
        fontSize: 10,
        letterSpacing: 2,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class EditorialField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final Widget? prefix;
  final Widget? suffix;
  final String? hint;
  final String? Function(String?)? validator;

  const EditorialField({
    super.key,
    required this.label,
    required this.controller,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.prefix,
    this.suffix,
    this.hint,
    this.validator,
  });

  OutlineInputBorder _border({bool focused = false, bool error = false}) {
    Color color;
    if (error) {
      color = Colors.redAccent.shade400;
    } else if (focused) {
      color = EditorialPalette.fieldBorderFocused;
    } else {
      color = EditorialPalette.fieldBorder;
    }
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: focused ? 1.4 : 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.roboto(
            color: EditorialPalette.textMuted,
            fontSize: 10,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          style: GoogleFonts.roboto(
            color: EditorialPalette.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          cursorColor: EditorialPalette.textPrimary,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.roboto(
              color: EditorialPalette.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
            isDense: true,
            filled: true,
            fillColor: EditorialPalette.fieldFill,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            prefixIcon: prefix == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 14, right: 0),
                    child: prefix,
                  ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0),
            suffixIcon: suffix == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: suffix,
                  ),
            suffixIconConstraints: const BoxConstraints(minWidth: 0),
            border: _border(),
            enabledBorder: _border(),
            focusedBorder: _border(focused: true),
            errorBorder: _border(error: true),
            focusedErrorBorder: _border(error: true),
            errorStyle: GoogleFonts.roboto(
              color: Colors.redAccent.shade400,
              fontSize: 11,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}

class EditorialContinueButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool submitting;
  final bool enabled;
  const EditorialContinueButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.submitting = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final active = enabled && !submitting;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: active ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: EditorialPalette.buttonBg,
            foregroundColor: EditorialPalette.buttonText,
            disabledBackgroundColor: EditorialPalette.buttonDisabled,
            disabledForegroundColor: Colors.white70,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
            ),
            elevation: 0,
          ),
          child: submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.roboto(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, size: 18),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Dashed-border circle used for the "Add a photo" picker.
class DottedCircle extends StatelessWidget {
  final double size;
  final Color color;
  final Widget? child;
  const DottedCircle({
    super.key,
    required this.size,
    required this.color,
    this.child,
  });
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DottedCirclePainter(color: color),
      child: SizedBox(
        width: size,
        height: size,
        child: Center(child: child),
      ),
    );
  }
}

class _DottedCirclePainter extends CustomPainter {
  final Color color;
  _DottedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    const dashCount = 28;
    const sweepPerDash = (3.14159 * 2) / dashCount;
    const dashSweep = sweepPerDash * 0.55;
    for (var i = 0; i < dashCount; i++) {
      final start = i * sweepPerDash;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        dashSweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DottedCirclePainter oldDelegate) =>
      oldDelegate.color != color;
}
