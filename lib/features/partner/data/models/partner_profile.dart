/// Mirror of the backend `PartnerProfile` row (migration 021). Drives
/// the Editorial onboarding flow: each step reads/writes a slice of
/// this model via the `/api/partner/profile` endpoint.
class PartnerProfile {
  final String id;
  final String userId;

  // Step 02 — Owner
  final String? profilePhotoUrl;
  final String legalFullName;
  final String contractEmail;
  final bool contractEmailVerified;
  final String phone;
  final bool phoneVerified;

  // Driver's license
  final String driversLicenseNumber;
  final String? driversLicenseFrontUrl;
  final String? driversLicenseBackUrl;
  final DateTime? driversLicenseDob;
  final bool driversLicenseFrscVerified;

  // Optional NIN
  final String? nin;
  final bool ninVerified;

  // Step 06 — Identity scan
  final String? selfieUrl;
  final bool livenessPassed;
  final double? faceMatchScore;

  /// One of: draft | pending | verified | rejected.
  final String identityStatus;
  final String? rejectionReason;

  PartnerProfile({
    required this.id,
    required this.userId,
    this.profilePhotoUrl,
    required this.legalFullName,
    required this.contractEmail,
    this.contractEmailVerified = false,
    required this.phone,
    this.phoneVerified = false,
    required this.driversLicenseNumber,
    this.driversLicenseFrontUrl,
    this.driversLicenseBackUrl,
    this.driversLicenseDob,
    this.driversLicenseFrscVerified = false,
    this.nin,
    this.ninVerified = false,
    this.selfieUrl,
    this.livenessPassed = false,
    this.faceMatchScore,
    this.identityStatus = 'draft',
    this.rejectionReason,
  });

  factory PartnerProfile.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return null;
      }
    }

    return PartnerProfile(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      profilePhotoUrl: json['profile_photo_url'] as String?,
      legalFullName: json['legal_full_name']?.toString() ?? '',
      contractEmail: json['contract_email']?.toString() ?? '',
      contractEmailVerified: json['contract_email_verified'] == true,
      phone: json['phone']?.toString() ?? '',
      phoneVerified: json['phone_verified'] == true,
      driversLicenseNumber: json['drivers_license_number']?.toString() ?? '',
      driversLicenseFrontUrl: json['drivers_license_front_url'] as String?,
      driversLicenseBackUrl: json['drivers_license_back_url'] as String?,
      driversLicenseDob: parseDate(json['drivers_license_dob']),
      driversLicenseFrscVerified: json['drivers_license_frsc_verified'] == true,
      nin: json['nin'] as String?,
      ninVerified: json['nin_verified'] == true,
      selfieUrl: json['selfie_url'] as String?,
      livenessPassed: json['liveness_passed'] == true,
      faceMatchScore: (json['face_match_score'] as num?)?.toDouble(),
      identityStatus: json['identity_status']?.toString() ?? 'draft',
      rejectionReason: json['rejection_reason'] as String?,
    );
  }
}
