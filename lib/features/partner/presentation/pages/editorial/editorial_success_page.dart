import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qent/features/partner/data/models/partner_listing.dart';
import 'package:qent/features/partner/presentation/controllers/partner_onboarding_controller.dart';
import 'package:qent/features/partner/presentation/pages/editorial/editorial_owner_page.dart'
    show EditorialContinueButton;
import 'package:qent/features/partner/presentation/pages/editorial/editorial_palette.dart';

/// Step 06 — "You're in." Final state.
///
/// On entry, looks up the user's draft listing, calls
/// `POST /partner/listings/:id/submit` to flip it from draft → submitted,
/// then displays the auto-minted `application_ref` (e.g. `QP-29841`).
///
/// The submit call is idempotent: if the user kills the app and comes
/// back, the server returns the existing submitted row instead of
/// erroring, so re-entering this screen is safe.
class EditorialSuccessPage extends ConsumerStatefulWidget {
  const EditorialSuccessPage({super.key});

  @override
  ConsumerState<EditorialSuccessPage> createState() =>
      _EditorialSuccessPageState();
}

class _EditorialSuccessPageState extends ConsumerState<EditorialSuccessPage> {
  PartnerListing? _listing;
  String? _errorMessage;
  bool _submitted = false;

  Future<void> _trySubmit(PartnerListing draft) async {
    if (_submitted) return;
    _submitted = true;
    try {
      final l = await ref
          .read(partnerOnboardingControllerProvider)
          .submitListing(listingId: draft.id);
      if (!mounted) return;
      setState(() => _listing = l);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _submitted = false; // allow retry from the button
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Wait for the draft listing to resolve, then fire submit. Once
    // submitted the draft provider returns null (no more drafts) — by
    // then we already hold the result in `_listing`.
    final draftAsync = ref.watch(partnerDraftListingProvider);
    if (_listing == null && _errorMessage == null) {
      draftAsync.whenData((draft) {
        if (draft != null) _trySubmit(draft);
      });
    }

    return Scaffold(
      backgroundColor: EditorialPalette.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBadge(),
                    const SizedBox(height: 26),
                    _buildTitle(),
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage ??
                          "Application sent. We'll have an answer in under 24 hours — usually less.",
                      style: GoogleFonts.roboto(
                        color: _errorMessage != null
                            ? Colors.redAccent.shade400
                            : EditorialPalette.textSecondary,
                        fontSize: 13.5,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildRefCard(),
                    const SizedBox(height: 28),
                    _buildTimeline(),
                    const SizedBox(height: 26),
                    _buildSupportLink(),
                  ],
                ),
              ),
            ),
            EditorialContinueButton(
              label: 'Back to dashboard',
              onPressed: () =>
                  Navigator.of(context).popUntil((r) => r.isFirst),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge() {
    return Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(
        color: EditorialPalette.textPrimary,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check, color: Colors.white, size: 28),
    );
  }

  Widget _buildTitle() {
    return Text(
      "You're in.",
      style: GoogleFonts.roboto(
        color: EditorialPalette.textPrimary,
        fontSize: 36,
        fontWeight: FontWeight.w800,
        height: 1.1,
        letterSpacing: -0.8,
      ),
    );
  }

  Widget _buildRefCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: EditorialPalette.fieldBorder),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'APPLICATION REFERENCE',
                style: GoogleFonts.roboto(
                  color: EditorialPalette.textMuted,
                  fontSize: 10,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _listing?.applicationRef ?? '· · ·',
                style: GoogleFonts.robotoMono(
                  color: _listing == null
                      ? EditorialPalette.textMuted
                      : EditorialPalette.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: _listing == null
                ? null
                : () {
                    Clipboard.setData(
                        ClipboardData(text: _listing!.applicationRef));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reference copied')),
                    );
                  },
            child: const Icon(Icons.copy_outlined,
                size: 18, color: EditorialPalette.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    final items = const [
      _TimelineItem(
        label: 'Application received',
        sub: 'Just now',
        state: _Step.done,
      ),
      _TimelineItem(
        label: 'Identity & docs review',
        sub: 'In progress · usually 4–12 hours',
        state: _Step.active,
      ),
      _TimelineItem(
        label: 'Listing goes live',
        sub: 'On approval',
        state: _Step.pending,
      ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EditorialPalette.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "WHAT HAPPENS NEXT",
            style: GoogleFonts.roboto(
              color: EditorialPalette.textMuted,
              fontSize: 10,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(items.length, (i) {
            return _TimelineRow(
              item: items[i],
              isLast: i == items.length - 1,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSupportLink() {
    return Center(
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.roboto(
            color: EditorialPalette.textSecondary,
            fontSize: 12.5,
            height: 1.5,
          ),
          children: [
            const TextSpan(text: 'Questions? '),
            TextSpan(
              text: 'hello@qent.online',
              style: GoogleFonts.roboto(
                color: EditorialPalette.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Step { done, active, pending }

class _TimelineItem {
  final String label;
  final String sub;
  final _Step state;
  const _TimelineItem({
    required this.label,
    required this.sub,
    required this.state,
  });
}

class _TimelineRow extends StatelessWidget {
  final _TimelineItem item;
  final bool isLast;
  const _TimelineRow({required this.item, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              _dot(),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1,
                    color: EditorialPalette.fieldBorder,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 14 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: GoogleFonts.roboto(
                      color: item.state == _Step.pending
                          ? EditorialPalette.textMuted
                          : EditorialPalette.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.sub,
                    style: GoogleFonts.roboto(
                      color: EditorialPalette.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot() {
    switch (item.state) {
      case _Step.done:
        return Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: EditorialPalette.textPrimary,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 12),
        );
      case _Step.active:
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: EditorialPalette.textPrimary,
              width: 2,
            ),
          ),
          alignment: Alignment.center,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: EditorialPalette.textPrimary,
              shape: BoxShape.circle,
            ),
          ),
        );
      case _Step.pending:
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: EditorialPalette.fieldBorder,
              width: 1.4,
            ),
          ),
        );
    }
  }
}
