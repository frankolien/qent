import 'package:qent/core/services/api_client.dart';
import 'package:qent/features/partner/data/models/partner_listing.dart';
import 'package:qent/features/partner/data/models/partner_profile.dart';

/// Thin wrapper over `ApiClient` for the partner v2 endpoints. Keeps
/// JSON shape concerns out of controllers/UI.
class PartnerV2DataSource {
  final ApiClient _api;
  PartnerV2DataSource({ApiClient? api}) : _api = api ?? ApiClient();

  /// GET /api/partner/profile — returns null when the user hasn't
  /// started onboarding yet (server replies 404).
  Future<PartnerProfile?> fetchProfile() async {
    final r = await _api.get('/partner/profile');
    if (r.statusCode == 404) return null;
    if (!r.isSuccess) {
      throw Exception('fetchProfile: ${r.errorMessage}');
    }
    return PartnerProfile.fromJson(r.body as Map<String, dynamic>);
  }

  /// POST /api/partner/profile — upsert step 02 data. Sends only the
  /// fields the server treats as updatable from the Owner screen;
  /// liveness / face match / FRSC verification flags are written
  /// later by their own endpoints.
  Future<PartnerProfile> upsertProfile({
    required String legalFullName,
    required String contractEmail,
    required String phone,
    required String driversLicenseNumber,
    DateTime? driversLicenseDob,
    String? profilePhotoUrl,
    String? driversLicenseFrontUrl,
    String? driversLicenseBackUrl,
  }) async {
    final body = <String, dynamic>{
      'legal_full_name': legalFullName,
      'contract_email': contractEmail,
      'phone': phone,
      'drivers_license_number': driversLicenseNumber,
      if (driversLicenseDob != null)
        'drivers_license_dob':
            driversLicenseDob.toIso8601String().split('T').first,
      if (profilePhotoUrl != null) 'profile_photo_url': profilePhotoUrl,
      if (driversLicenseFrontUrl != null)
        'drivers_license_front_url': driversLicenseFrontUrl,
      if (driversLicenseBackUrl != null)
        'drivers_license_back_url': driversLicenseBackUrl,
    };
    final r = await _api.post('/partner/profile', body: body);
    if (!r.isSuccess) {
      throw Exception('upsertProfile: ${r.errorMessage}');
    }
    return PartnerProfile.fromJson(r.body as Map<String, dynamic>);
  }

  /// GET /api/partner/listings — every listing the host owns. Drives
  /// the "your listings" section on the host dashboard, and the entry
  /// point for "Add new listing" on already-connected hosts.
  Future<List<PartnerListing>> fetchListings() async {
    final r = await _api.get('/partner/listings');
    if (!r.isSuccess) {
      throw Exception('fetchListings: ${r.errorMessage}');
    }
    final raw = r.body;
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(PartnerListing.fromJson)
        .toList();
  }

  /// GET /api/partner/listings/draft — current in-progress listing for
  /// resume. Returns null when no draft exists.
  Future<PartnerListing?> fetchDraftListing() async {
    final r = await _api.get('/partner/listings/draft');
    if (r.statusCode == 404) return null;
    if (!r.isSuccess) {
      throw Exception('fetchDraftListing: ${r.errorMessage}');
    }
    return PartnerListing.fromJson(r.body as Map<String, dynamic>);
  }

  /// POST /api/partner/listings — create or upsert the host's draft
  /// listing (step 03). Server reuses the existing draft if any so a
  /// host going Back/Continue doesn't accumulate ghost rows.
  Future<PartnerListing> upsertListing({
    required String tier,
    required String brand,
    required String model,
    int? year,
    String? color,
    required String plateNumber,
  }) async {
    final r = await _api.post('/partner/listings', body: {
      'tier': tier,
      'brand': brand,
      'model': model,
      if (year != null) 'year': year,
      if (color != null) 'color': color,
      'plate_number': plateNumber,
    });
    if (!r.isSuccess) {
      throw Exception('upsertListing: ${r.errorMessage}');
    }
    return PartnerListing.fromJson(r.body as Map<String, dynamic>);
  }

  /// PUT /api/partner/listings/:id/photos — replace the listing's
  /// photo array. Returns the updated listing plus a `meets_minimum`
  /// flag the UI uses to enable/disable Continue.
  Future<({PartnerListing listing, int minRequired, bool meetsMinimum})>
      updateListingPhotos({
    required String listingId,
    required List<String> photos,
  }) async {
    final r = await _api.put(
      '/partner/listings/$listingId/photos',
      body: {'photos': photos},
    );
    if (!r.isSuccess) {
      throw Exception('updateListingPhotos: ${r.errorMessage}');
    }
    final body = r.body as Map<String, dynamic>;
    return (
      listing:
          PartnerListing.fromJson(body['listing'] as Map<String, dynamic>),
      minRequired: (body['min_required'] as num?)?.toInt() ?? 3,
      meetsMinimum: body['meets_minimum'] == true,
    );
  }

  /// POST /api/partner/email/mark-verified — flip the
  /// `contract_email_verified` flag on the partner profile after the
  /// global `/auth/verify-code` returned `verified: true`. The server
  /// re-checks the verification_codes table itself; we just trigger it.
  Future<void> markEmailVerified(String email) async {
    final r = await _api
        .post('/partner/email/mark-verified', body: {'email': email});
    if (!r.isSuccess) {
      throw Exception('markEmailVerified: ${r.errorMessage}');
    }
  }

  /// POST /api/partner/listings/:id/docs — submit Step 05 documents.
  /// Driver identity is verified out-of-band via Sumsub; server gates
  /// this call on `kyc_tier >= 1` and returns 412 with
  /// `verify_identity_required` if the host hasn't completed it. Plate
  /// cross-check still runs synchronously via Prembly.
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
    final body = <String, dynamic>{
      if (vehicleRegistrationUrl != null)
        'vehicle_registration_url': vehicleRegistrationUrl,
      if (insuranceCertificateUrl != null)
        'insurance_certificate_url': insuranceCertificateUrl,
      if (insurancePolicyNumber != null)
        'insurance_policy_number': insurancePolicyNumber,
      'is_registered_owner': isRegisteredOwner,
    };
    final r = await _api.post('/partner/listings/$listingId/docs', body: body);
    if (!r.isSuccess) {
      throw PartnerDocsException(r.statusCode, r.errorMessage,
          isIdentityRequired: r.statusCode == 412);
    }
    final json = r.body as Map<String, dynamic>;
    return (
      listing: PartnerListing.fromJson(json['listing'] as Map<String, dynamic>),
      vehiclePlateVerified: json['vehicle_plate_verified'] == true,
      ownerConsentRequired: json['owner_consent_required'] == true,
    );
  }

  Future<PartnerListing> setListingPricing({
    required String listingId,
    required double pricePerDay,
    required String location,
    double? latitude,
    double? longitude,
    String? description,
  }) async {
    final r = await _api.post(
      '/partner/listings/$listingId/pricing',
      body: {
        'price_per_day': pricePerDay,
        'location': location,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (description != null && description.isNotEmpty) 'description': description,
      },
    );
    if (!r.isSuccess) {
      throw Exception('setListingPricing: ${r.errorMessage}');
    }
    return PartnerListing.fromJson(r.body as Map<String, dynamic>);
  }

  Future<PartnerListing> submitListing({required String listingId}) async {
    final r = await _api.post('/partner/listings/$listingId/submit');
    if (!r.isSuccess) {
      throw Exception('submitListing: ${r.errorMessage}');
    }
    final json = r.body as Map<String, dynamic>;
    return PartnerListing.fromJson(json['listing'] as Map<String, dynamic>);
  }

  /// POST /api/partner/listings/:id/owner-consent — Step 04b. Only
  /// callable when the previous docs step set
  /// `owner_consent_required = true`.
  Future<PartnerListing> submitOwnerConsent({
    required String listingId,
    required String ownerRelationship,
    String? ownerConsentLetterUrl,
    required String ownerConsentPhone,
    String? ownerNin,
  }) async {
    final body = <String, dynamic>{
      'owner_relationship': ownerRelationship,
      'owner_consent_phone': ownerConsentPhone,
      if (ownerConsentLetterUrl != null)
        'owner_consent_letter_url': ownerConsentLetterUrl,
      if (ownerNin != null) 'owner_nin': ownerNin,
    };
    final r = await _api
        .post('/partner/listings/$listingId/owner-consent', body: body);
    if (!r.isSuccess) {
      throw Exception('submitOwnerConsent: ${r.errorMessage}');
    }
    final json = r.body as Map<String, dynamic>;
    return PartnerListing.fromJson(json['listing'] as Map<String, dynamic>);
  }
}

/// Raised when /partner/listings/:id/docs rejects the submit. The
/// 412 path (`verify_identity_required`) is the one the UI cares
/// about — it means the host hasn't finished Sumsub yet.
class PartnerDocsException implements Exception {
  final int statusCode;
  final String message;
  final bool isIdentityRequired;
  PartnerDocsException(this.statusCode, this.message,
      {this.isIdentityRequired = false});
  @override
  String toString() => message;
}
