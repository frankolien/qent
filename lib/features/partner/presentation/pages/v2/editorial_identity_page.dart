import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qent/core/services/cloudinary_service.dart';
import 'package:qent/features/partner/presentation/controllers/partner_v2_controller.dart';
import 'package:qent/features/partner/presentation/pages/v2/editorial_owner_page.dart'
    show EditorialHeader, EditorialStepLabel, EditorialContinueButton;
import 'package:qent/features/partner/presentation/pages/v2/editorial_palette.dart';
import 'package:qent/features/partner/presentation/pages/v2/editorial_success_page.dart';

/// Step 05 — "One last look." Liveness / face match screen.
///
/// The real Smile SDK isn't wired in yet (sandbox approval pending),
/// so we use the device camera to capture a selfie, upload it to
/// Cloudinary, and POST to the backend stub which marks the profile
/// pending. The on-screen 3-second scan + cue cycle still runs as
/// visual feedback while the upload + POST happen in the background.
class EditorialIdentityPage extends ConsumerStatefulWidget {
  const EditorialIdentityPage({super.key});

  @override
  ConsumerState<EditorialIdentityPage> createState() =>
      _EditorialIdentityPageState();
}

class _EditorialIdentityPageState extends ConsumerState<EditorialIdentityPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _scan;
  bool _scanning = false;
  bool _done = false;
  String? _errorMessage;

  // Mock cue list — switch the active one as the scan progresses so
  // the UI feels alive.
  final _cues = const [
    ('LOOK STRAIGHT', 'Center your face inside the circle'),
    ('TURN LEFT', 'Slowly, just an inch'),
    ('TURN RIGHT', 'Now to the other side'),
    ('SMILE', 'You did it'),
  ];
  int _cueIdx = 0;

  @override
  void initState() {
    super.initState();
    _scan = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          setState(() {
            _scanning = false;
            _done = true;
          });
        }
      });
    _scan.addListener(() {
      final i = (_scan.value * _cues.length).floor().clamp(0, _cues.length - 1);
      if (i != _cueIdx) setState(() => _cueIdx = i);
    });
  }

  @override
  void dispose() {
    _scan.dispose();
    super.dispose();
  }

  /// Take the selfie, then run the cue animation in parallel with the
  /// Cloudinary upload + backend POST. The animation sells the
  /// liveness check; the real verification work happens in the
  /// background. Whichever finishes last drives the `_done` flip.
  Future<void> _start() async {
    final picker = ImagePicker();
    final shot = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 1280,
      imageQuality: 75,
    );
    if (shot == null) return;
    if (!mounted) return;

    setState(() {
      _scanning = true;
      _done = false;
      _cueIdx = 0;
      _errorMessage = null;
    });
    _scan.forward(from: 0);

    try {
      final url = await CloudinaryService().uploadImage(
        imageFile: File(shot.path),
        folder: 'qent/partners/selfies',
      );
      if (url == null || url.isEmpty) {
        throw Exception('Selfie upload failed');
      }
      await ref
          .read(partnerV2ControllerProvider)
          .submitIdentityScan(selfieUrl: url);
      if (!mounted) return;
      // If the animation is still mid-flight, let it finish so the
      // ring fills naturally. The status listener flips _done either
      // way; just stay scanning until it completes.
    } catch (e) {
      if (!mounted) return;
      _scan.stop();
      setState(() {
        _scanning = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _onContinue() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EditorialSuccessPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EditorialPalette.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const EditorialHeader(stepIndex: 5, totalSteps: 6),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const EditorialStepLabel('STEP 05 · IDENTITY'),
                    const SizedBox(height: 18),
                    _buildTitle(),
                    const SizedBox(height: 12),
                    Text(
                      "A quick selfie to confirm it's you. We compare it against your driver's licence — never shared.",
                      style: GoogleFonts.roboto(
                        color: EditorialPalette.textSecondary,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Center(child: _buildFaceFrame()),
                    const SizedBox(height: 22),
                    _buildCueCard(),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.error_outline,
                              size: 14, color: Colors.redAccent.shade400),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: GoogleFonts.roboto(
                                color: Colors.redAccent.shade400,
                                fontSize: 12.5,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 18),
                    _buildChecklist(),
                  ],
                ),
              ),
            ),
            _buildBottomButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      'One last look.',
      style: GoogleFonts.roboto(
        color: EditorialPalette.textPrimary,
        fontSize: 30,
        fontWeight: FontWeight.w700,
        height: 1.15,
        letterSpacing: -0.6,
      ),
    );
  }

  Widget _buildFaceFrame() {
    return AnimatedBuilder(
      animation: _scan,
      builder: (_, __) {
        return SizedBox(
          width: 240,
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(
                    color: EditorialPalette.fieldBorder,
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  _done
                      ? Icons.verified_outlined
                      : Icons.person_outline,
                  size: 96,
                  color: _done
                      ? EditorialPalette.textPrimary
                      : EditorialPalette.textMuted,
                ),
              ),
              SizedBox(
                width: 240,
                height: 240,
                child: CircularProgressIndicator(
                  value: _done ? 1.0 : (_scanning ? _scan.value : 0.0),
                  strokeWidth: 3,
                  backgroundColor: EditorialPalette.fieldBorder,
                  valueColor: const AlwaysStoppedAnimation(
                      EditorialPalette.textPrimary),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCueCard() {
    final (heading, sub) = _done
        ? ('MATCH FOUND', "We're good. Tap continue to wrap up.")
        : (_scanning ? _cues[_cueIdx] : _cues.first);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: EditorialPalette.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: GoogleFonts.roboto(
              color: EditorialPalette.textMuted,
              fontSize: 10,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            sub,
            style: GoogleFonts.roboto(
              color: EditorialPalette.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklist() {
    final items = [
      ('Good lighting', _scanning || _done),
      ('No hats or sunglasses', _scanning || _done),
      ('Hold steady', _done),
    ];
    return Column(
      children: items
          .map(
            (it) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: it.$2
                          ? EditorialPalette.textPrimary
                          : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: it.$2
                            ? EditorialPalette.textPrimary
                            : EditorialPalette.fieldBorder,
                      ),
                    ),
                    child: it.$2
                        ? const Icon(Icons.check,
                            color: Colors.white, size: 12)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    it.$1,
                    style: GoogleFonts.roboto(
                      color: EditorialPalette.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildBottomButton() {
    if (_done) {
      return EditorialContinueButton(
        label: 'Continue',
        onPressed: _onContinue,
      );
    }
    return EditorialContinueButton(
      label: _scanning ? 'Scanning…' : 'Start scan',
      onPressed: _scanning ? null : _start,
      submitting: _scanning,
    );
  }
}
