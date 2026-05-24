/// Mirror of the backend `PartnerListing` row (migration 021). Each
/// listing represents one car a host wants to put up; profiles hold
/// the once-per-host KYC, listings hold the per-vehicle KYC + state.
class PartnerListing {
  final String id;
  final String applicationRef;
  final String profileId;
  final String userId;
  final String? carId;

  // Step 03 — Vehicle
  final String tier; // regular | luxury | exotic
  final String brand;
  final String model;
  final int? year;
  final String? color;
  final String plateNumber;

  // Step 04 — Photos
  final List<String> photos;

  // Step 05 — Vehicle registration / FRSC
  final String? vehicleRegistrationUrl;
  final bool vehiclePlateFrscVerified;
  final String? registeredOwnerName;
  final bool? ownerMatch;

  // Step 05b — Owner consent (set when ownerMatch == false)
  final bool ownerConsentRequired;
  final String? ownerRelationship;
  final String? ownerConsentLetterUrl;
  final String? ownerConsentPhone;
  final bool ownerConsentPhoneVerified;
  final String? ownerNin;
  final bool ownerNinVerified;

  // Step 05 — Insurance / NIID
  final String? insuranceCertificateUrl;
  final String? insurancePolicyNumber;
  final bool insuranceNiidVerified;

  // Step 07 — Pricing
  final double? pricePerDay;
  final String? location;
  final double? latitude;
  final double? longitude;
  final String? description;

  /// One of: draft | submitted | in_review | approved | rejected.
  final String listingStatus;
  final String? rejectionReason;

  PartnerListing({
    required this.id,
    required this.applicationRef,
    required this.profileId,
    required this.userId,
    this.carId,
    required this.tier,
    required this.brand,
    required this.model,
    this.year,
    this.color,
    required this.plateNumber,
    this.photos = const [],
    this.vehicleRegistrationUrl,
    this.vehiclePlateFrscVerified = false,
    this.registeredOwnerName,
    this.ownerMatch,
    this.ownerConsentRequired = false,
    this.ownerRelationship,
    this.ownerConsentLetterUrl,
    this.ownerConsentPhone,
    this.ownerConsentPhoneVerified = false,
    this.ownerNin,
    this.ownerNinVerified = false,
    this.insuranceCertificateUrl,
    this.insurancePolicyNumber,
    this.insuranceNiidVerified = false,
    this.pricePerDay,
    this.location,
    this.latitude,
    this.longitude,
    this.description,
    this.listingStatus = 'draft',
    this.rejectionReason,
  });

  factory PartnerListing.fromJson(Map<String, dynamic> json) {
    final rawPhotos = json['photos'];
    final photos = rawPhotos is List
        ? rawPhotos.map((e) => e.toString()).toList()
        : <String>[];
    return PartnerListing(
      id: json['id']?.toString() ?? '',
      applicationRef: json['application_ref']?.toString() ?? '',
      profileId: json['profile_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      carId: json['car_id'] as String?,
      tier: json['tier']?.toString() ?? 'regular',
      brand: json['brand']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      year: (json['year'] as num?)?.toInt(),
      color: json['color'] as String?,
      plateNumber: json['plate_number']?.toString() ?? '',
      photos: photos,
      vehicleRegistrationUrl: json['vehicle_registration_url'] as String?,
      vehiclePlateFrscVerified: json['vehicle_plate_frsc_verified'] == true,
      registeredOwnerName: json['registered_owner_name'] as String?,
      ownerMatch: json['owner_match'] as bool?,
      ownerConsentRequired: json['owner_consent_required'] == true,
      ownerRelationship: json['owner_relationship'] as String?,
      ownerConsentLetterUrl: json['owner_consent_letter_url'] as String?,
      ownerConsentPhone: json['owner_consent_phone'] as String?,
      ownerConsentPhoneVerified: json['owner_consent_phone_verified'] == true,
      ownerNin: json['owner_nin'] as String?,
      ownerNinVerified: json['owner_nin_verified'] == true,
      insuranceCertificateUrl: json['insurance_certificate_url'] as String?,
      insurancePolicyNumber: json['insurance_policy_number'] as String?,
      insuranceNiidVerified: json['insurance_niid_verified'] == true,
      pricePerDay: (json['price_per_day'] as num?)?.toDouble(),
      location: json['location'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      description: json['description'] as String?,
      listingStatus: json['listing_status']?.toString() ?? 'draft',
      rejectionReason: json['rejection_reason'] as String?,
    );
  }
}
