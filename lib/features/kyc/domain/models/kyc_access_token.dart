/// V2 §6.7 — short-lived token the Sumsub WebSDK / mobile SDK uses
/// to authenticate the inline verification flow.
class KycAccessToken {
  final String token;
  final String levelName;
  final DateTime expiresAt;

  const KycAccessToken({
    required this.token,
    required this.levelName,
    required this.expiresAt,
  });

  factory KycAccessToken.fromJson(Map<String, dynamic> json) {
    return KycAccessToken(
      token: json['token'] as String,
      levelName: json['level_name'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }
}
