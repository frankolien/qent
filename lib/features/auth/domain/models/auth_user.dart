/// Replaces Firebase User (fb.User) with our own user model
/// backed by the Rust backend JWT auth system.
class AuthUser {
  final String uid;
  final String email;
  final String fullName;
  final String? phone;
  final String role;
  final String? profilePhotoUrl;
  final String verificationStatus;
  final double walletBalance;
  final bool isActive;
  final String country;
  final DateTime createdAt;

  AuthUser({
    required this.uid,
    required this.email,
    required this.fullName,
    this.phone,
    required this.role,
    this.profilePhotoUrl,
    required this.verificationStatus,
    required this.walletBalance,
    required this.isActive,
    required this.country,
    required this.createdAt,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      uid: json['id'] ?? '',
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? '',
      phone: json['phone'],
      role: json['role'] ?? 'Renter',
      profilePhotoUrl: json['profile_photo_url'],
      verificationStatus: json['verification_status'] ?? 'Pending',
      walletBalance: (json['wallet_balance'] as num?)?.toDouble() ?? 0.0,
      isActive: json['is_active'] ?? true,
      country: json['country'] ?? 'Nigeria',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'phone': phone,
      'role': role,
      'profilePhotoUrl': profilePhotoUrl,
      'verificationStatus': verificationStatus,
      'walletBalance': walletBalance,
      'isActive': isActive,
      'country': country,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Convert to UserProfile for backward compatibility.
  /// This allows existing code that uses UserProfile to keep working.
  Map<String, dynamic> toUserProfileMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'country': country,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
