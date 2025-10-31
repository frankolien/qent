class UserProfile {
  final String uid;
  final String email;
  final String fullName;
  final String country;
  final DateTime createdAt;

  UserProfile({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.country,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'country': country,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] as String,
      email: map['email'] as String,
      fullName: map['fullName'] as String,
      country: map['country'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}

