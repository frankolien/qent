import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qent/core/services/cloudinary_service.dart';
import 'package:qent/core/utils/friendly_error.dart';
import 'package:qent/features/partner/data/models/partner_listing.dart';
import 'package:qent/features/partner/presentation/controllers/partner_v2_controller.dart';
import 'package:qent/features/partner/presentation/pages/v2/editorial_documents_page.dart';
import 'package:qent/features/partner/presentation/pages/v2/editorial_owner_page.dart'
    show EditorialHeader, EditorialStepLabel, EditorialContinueButton;
import 'package:qent/features/partner/presentation/pages/v2/editorial_palette.dart';

/// Step 03 — "Show it off." Seven ordered slots (cover + 6 angles).
/// Each pick uploads to Cloudinary in the background; on Continue we
/// PUT the URL list to `/api/partner/listings/:id/photos`.
class EditorialPhotosPage extends ConsumerStatefulWidget {
  const EditorialPhotosPage({super.key});

  @override
  ConsumerState<EditorialPhotosPage> createState() =>
      _EditorialPhotosPageState();
}

class _PhotoSlot {
  final String index;
  final String label;
  String? localPath;
  String? remoteUrl;
  bool uploading;
  _PhotoSlot({required this.index, required this.label})
      : uploading = false;
}

class _EditorialPhotosPageState extends ConsumerState<EditorialPhotosPage> {
  final _slots = <_PhotoSlot>[
    _PhotoSlot(index: '01', label: 'Cover · Hero shot'),
    _PhotoSlot(index: '02', label: 'Front 3/4'),
    _PhotoSlot(index: '03', label: 'Rear 3/4'),
    _PhotoSlot(index: '04', label: 'Driver side'),
    _PhotoSlot(index: '05', label: 'Passenger side'),
    _PhotoSlot(index: '06', label: 'Interior'),
    _PhotoSlot(index: '07', label: 'Dashboard'),
  ];

  String? _listingId;
  bool _hydrated = false;
  bool _submitting = false;

  /// Fill the slots from the server-side draft (cover + angles in
  /// stored order). Idempotent — only fires once so later cache
  /// invalidations don't overwrite a fresh local pick.
  void _hydrate(PartnerListing? l) {
    if (_hydrated || l == null) return;
    _hydrated = true;
    _listingId = l.id;
    for (var i = 0; i < _slots.length && i < l.photos.length; i++) {
      _slots[i].remoteUrl = l.photos[i];
    }
    setState(() {});
  }

  // A slot counts as "filled" once Cloudinary has handed back a URL
  // (or one was hydrated from the draft). Local-only previews don't
  // count — they'd lose data on a crash.
  int get _filledCount =>
      _slots.where((s) => s.remoteUrl != null && s.remoteUrl!.isNotEmpty).length;
  bool get _meetsMin => _filledCount >= 3;
  bool get _anyUploading => _slots.any((s) => s.uploading);

  Future<void> _pickFor(_PhotoSlot slot) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 6),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: EditorialPalette.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined,
                  color: EditorialPalette.textPrimary),
              title: Text('Take photo',
                  style: GoogleFonts.roboto(
                      color: EditorialPalette.textPrimary,
                      fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_outlined,
                  color: EditorialPalette.textPrimary),
              title: Text('Choose from library',
                  style: GoogleFonts.roboto(
                      color: EditorialPalette.textPrimary,
                      fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      imageQuality: 75,
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
        folder: 'qent/listings',
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

  Future<void> _onContinue() async {
    if (_submitting) return;
    if (_anyUploading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hang on — uploads finishing')),
      );
      return;
    }
    if (_filledCount < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least 3 photos to continue')),
      );
      return;
    }
    if (_listingId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listing not loaded yet — go back and try again')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final urls = _slots
          .map((s) => s.remoteUrl)
          .whereType<String>()
          .where((u) => u.isNotEmpty)
          .toList();
      await ref.read(partnerV2ControllerProvider).saveListingPhotos(
            listingId: _listingId!,
            photos: urls,
          );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const EditorialDocumentsPage()),
      );
    } catch (e, st) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e, tag: 'Partner/photos', stack: st))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Resume from the server-side draft so a host who picked photos
    // earlier sees them already filled in.
    ref.listen<AsyncValue<PartnerListing?>>(partnerDraftListingProvider,
        (_, next) {
      next.whenData(_hydrate);
    });
    ref.watch(partnerDraftListingProvider).whenData(_hydrate);

    return Scaffold(
      backgroundColor: EditorialPalette.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const EditorialHeader(stepIndex: 3, totalSteps: 6),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const EditorialStepLabel('STEP 03 · PHOTOS'),
                    const SizedBox(height: 18),
                    _buildTitle(),
                    const SizedBox(height: 12),
                    _buildSubtitle(),
                    const SizedBox(height: 28),
                    _buildSlot(_slots[0], height: 220),
                    const SizedBox(height: 12),
                    _buildAngleGrid(),
                  ],
                ),
              ),
            ),
            EditorialContinueButton(
              label: 'Continue · $_filledCount / 7 added',
              onPressed: _onContinue,
              enabled: _meetsMin,
              submitting: _submitting,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      'Show it off.',
      style: GoogleFonts.roboto(
        color: EditorialPalette.textPrimary,
        fontSize: 30,
        fontWeight: FontWeight.w700,
        height: 1.15,
        letterSpacing: -0.6,
      ),
    );
  }

  Widget _buildSubtitle() {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.roboto(
          color: EditorialPalette.textSecondary,
          fontSize: 13,
          height: 1.5,
        ),
        children: const [
          TextSpan(text: 'Listings with all 6 angles get booked '),
          TextSpan(
            text: '3.4× faster',
            style: TextStyle(
                color: EditorialPalette.textPrimary,
                fontWeight: FontWeight.w700),
          ),
          TextSpan(text: '.'),
        ],
      ),
    );
  }

  Widget _buildAngleGrid() {
    final children = <Widget>[];
    for (var i = 1; i < _slots.length; i += 2) {
      final left = _slots[i];
      final right = (i + 1 < _slots.length) ? _slots[i + 1] : null;
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            children: [
              Expanded(child: _buildSlot(left, height: 130)),
              const SizedBox(width: 12),
              Expanded(
                child: right == null
                    ? const SizedBox.shrink()
                    : _buildSlot(right, height: 130),
              ),
            ],
          ),
        ),
      );
    }
    return Column(children: children);
  }

  Widget _buildSlot(_PhotoSlot slot, {required double height}) {
    // Show whichever image we have. Local file paints the moment the
    // user picks; remote URL takes over once Cloudinary returns. The
    // slot is "done" when both upload + URL exist.
    final hasLocal = slot.localPath != null;
    final hasRemote = slot.remoteUrl != null && slot.remoteUrl!.isNotEmpty;
    final hasImage = hasLocal || hasRemote;
    final done = hasRemote && !slot.uploading;

    final ImageProvider? image = hasLocal
        ? FileImage(File(slot.localPath!))
        : (hasRemote ? NetworkImage(slot.remoteUrl!) : null);

    return GestureDetector(
      onTap: slot.uploading ? null : () => _pickFor(slot),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: done
                ? EditorialPalette.textPrimary
                : EditorialPalette.fieldBorder,
            width: done ? 1.2 : 1,
          ),
          image: image == null
              ? null
              : DecorationImage(image: image, fit: BoxFit.cover),
        ),
        child: Stack(
          children: [
            if (!hasImage)
              const Center(
                child: Icon(
                  Icons.add_rounded,
                  color: EditorialPalette.textMuted,
                  size: 30,
                ),
              ),
            if (slot.uploading)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            Positioned(
              left: 12,
              bottom: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: hasImage
                      ? Colors.black.withValues(alpha: 0.55)
                      : EditorialPalette.background,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${slot.index} · ${slot.label}',
                  style: GoogleFonts.roboto(
                    color: hasImage
                        ? Colors.white
                        : EditorialPalette.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            if (done)
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: EditorialPalette.textPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
