import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/features/partner/data/datasources/partner_onboarding_datasource.dart';
import 'package:qent/features/partner/data/models/partner_listing.dart';
import 'package:qent/features/partner/data/models/partner_profile.dart';

/// Singleton-ish data source. No state of its own beyond the global
/// `ApiClient`, so a plain `Provider` is fine.
final partnerOnboardingDataSourceProvider = Provider<PartnerOnboardingDataSource>((ref) {
  return PartnerOnboardingDataSource();
});

/// Reactive cache of the current user's partner profile. `null` data
/// means the user hasn't started onboarding (server returned 404).
/// Watched by the Editorial flow to decide where to drop the user
/// in: no profile → step 02 Owner; profile in `draft` → resume at the
/// last step; profile `verified` → skip identity, go to Vehicle for
/// the next listing.
final partnerProfileProvider = FutureProvider<PartnerProfile?>((ref) async {
  ref.keepAlive();
  return ref.read(partnerOnboardingDataSourceProvider).fetchProfile();
});

/// Reactive cache of the host's current draft listing. `null` means
/// no draft — either the host hasn't started Step 03 yet, or every
/// listing they have is past `draft`. Used by Vehicle / Photos /
/// Documents screens to load the in-progress row and write back to it.
final partnerDraftListingProvider =
    FutureProvider<PartnerListing?>((ref) async {
  ref.keepAlive();
  return ref.read(partnerOnboardingDataSourceProvider).fetchDraftListing();
});

/// All listings owned by the host, newest first. Powers the host
/// dashboard's "your listings" section and the "Add new listing" flow.
final partnerListingsProvider =
    FutureProvider<List<PartnerListing>>((ref) async {
  ref.keepAlive();
  return ref.read(partnerOnboardingDataSourceProvider).fetchListings();
});

/// Action controller — exposes the mutating calls. Each step page calls
/// the relevant method and awaits the result to navigate forward.
class PartnerOnboardingController {
  final Ref _ref;
  PartnerOnboardingController(this._ref);

  PartnerOnboardingDataSource get _ds => _ref.read(partnerOnboardingDataSourceProvider);

  Future<PartnerProfile> saveOwnerStep({
    required String legalFullName,
    required String contractEmail,
    required String phone,
    required String driversLicenseNumber,
    DateTime? driversLicenseDob,
    String? profilePhotoUrl,
  }) async {
    final profile = await _ds.upsertProfile(
      legalFullName: legalFullName,
      contractEmail: contractEmail,
      phone: phone,
      driversLicenseNumber: driversLicenseNumber,
      driversLicenseDob: driversLicenseDob,
      profilePhotoUrl: profilePhotoUrl,
    );
    // Refresh the cached provider so any other watchers see the new
    // state immediately (e.g. a "resume" router that might re-check
    // identity_status).
    _ref.invalidate(partnerProfileProvider);
    return profile;
  }

  /// Step 03 — create / update the draft listing. Server reuses any
  /// existing draft for this user, so re-submitting from the back
  /// button doesn't accumulate stale rows.
  Future<PartnerListing> saveVehicleStep({
    required String tier,
    required String brand,
    required String model,
    int? year,
    String? color,
    required String plateNumber,
  }) async {
    final listing = await _ds.upsertListing(
      tier: tier,
      brand: brand,
      model: model,
      year: year,
      color: color,
      plateNumber: plateNumber,
    );
    _ref.invalidate(partnerDraftListingProvider);
    _ref.invalidate(partnerListingsProvider);
    return listing;
  }

  /// Step 04 — replace the listing's photo set. Returns whether the
  /// new count satisfies the server's minimum (driving Continue
  /// enable/disable in the UI).
  Future<({PartnerListing listing, int minRequired, bool meetsMinimum})>
      saveListingPhotos({
    required String listingId,
    required List<String> photos,
  }) async {
    final out = await _ds.updateListingPhotos(
      listingId: listingId,
      photos: photos,
    );
    _ref.invalidate(partnerDraftListingProvider);
    _ref.invalidate(partnerListingsProvider);
    return out;
  }

  /// Step 01 sub-step — flip `contract_email_verified` on the profile
  /// after a successful `/auth/verify-code`. Invalidates the profile
  /// cache so any watcher (resume router, dashboard) sees the new
  /// state immediately.
  Future<void> markEmailVerified(String email) async {
    await _ds.markEmailVerified(email);
    _ref.invalidate(partnerProfileProvider);
  }

  /// Step 05 — submit vehicle documents. Driver identity is verified
  /// out-of-band via Sumsub; server returns 412 if the host hasn't
  /// finished it. Plate cross-check still runs synchronously.
  Future<({
    PartnerListing listing,
    bool vehiclePlateVerified,
    bool ownerConsentRequired,
  })> submitListingDocs({
    required String listingId,
    String? vehicleRegistrationUrl,
    String? insuranceCertificateUrl,
    String? insurancePolicyNumber,
    required bool isRegisteredOwner,
  }) async {
    final out = await _ds.submitListingDocs(
      listingId: listingId,
      vehicleRegistrationUrl: vehicleRegistrationUrl,
      insuranceCertificateUrl: insuranceCertificateUrl,
      insurancePolicyNumber: insurancePolicyNumber,
      isRegisteredOwner: isRegisteredOwner,
    );
    _ref.invalidate(partnerProfileProvider);
    _ref.invalidate(partnerDraftListingProvider);
    _ref.invalidate(partnerListingsProvider);
    return out;
  }

  /// Step 06 — flip the listing from draft → submitted. Returns the
  /// updated row so the success screen can display the application
  /// reference (`QP-XXXXX`).
  Future<PartnerListing> saveListingPricing({
    required String listingId,
    required double pricePerDay,
    required String location,
    double? latitude,
    double? longitude,
    String? description,
  }) async {
    final l = await _ds.setListingPricing(
      listingId: listingId,
      pricePerDay: pricePerDay,
      location: location,
      latitude: latitude,
      longitude: longitude,
      description: description,
    );
    _ref.invalidate(partnerDraftListingProvider);
    _ref.invalidate(partnerListingsProvider);
    return l;
  }

  Future<PartnerListing> submitListing({required String listingId}) async {
    final l = await _ds.submitListing(listingId: listingId);
    _ref.invalidate(partnerDraftListingProvider);
    _ref.invalidate(partnerListingsProvider);
    return l;
  }

  /// Step 04b — submit owner consent. Only fires when the docs step
  /// flagged `owner_consent_required = true`.
  Future<PartnerListing> submitOwnerConsent({
    required String listingId,
    required String ownerRelationship,
    String? ownerConsentLetterUrl,
    required String ownerConsentPhone,
    String? ownerNin,
  }) async {
    final listing = await _ds.submitOwnerConsent(
      listingId: listingId,
      ownerRelationship: ownerRelationship,
      ownerConsentLetterUrl: ownerConsentLetterUrl,
      ownerConsentPhone: ownerConsentPhone,
      ownerNin: ownerNin,
    );
    _ref.invalidate(partnerDraftListingProvider);
    _ref.invalidate(partnerListingsProvider);
    return listing;
  }
}

final partnerOnboardingControllerProvider = Provider<PartnerOnboardingController>((ref) {
  return PartnerOnboardingController(ref);
});
