/// V2 §6.3 — entry from the `countries` reference table.
class Country {
  final String iso2;
  final String name;
  final String currencyCode;
  final String phoneCode;
  final bool supported;
  final String? plateFormatHint;

  const Country({
    required this.iso2,
    required this.name,
    required this.currencyCode,
    required this.phoneCode,
    required this.supported,
    this.plateFormatHint,
  });

  factory Country.fromJson(Map<String, dynamic> json) => Country(
        iso2: json['iso2'] as String,
        name: json['name'] as String,
        currencyCode: json['currency_code'] as String,
        phoneCode: json['phone_code'] as String,
        supported: json['supported'] as bool? ?? false,
        plateFormatHint: json['plate_format_hint'] as String?,
      );

  /// Unicode flag emoji from the ISO-2 code.
  String get flagEmoji {
    if (iso2.length != 2) return '';
    final upper = iso2.toUpperCase();
    final first = upper.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final second = upper.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(first) + String.fromCharCode(second);
  }
}
