enum PaymentMethodType {
  cash,
  card,
  applePay,
  paystack,
}

enum CardBrand {
  visa,
  mastercard,
  verve,
  unknown,
}

class PaymentMethod {
  final PaymentMethodType type;
  final bool isDefault;
  final String? name;

  PaymentMethod({
    required this.type,
    this.isDefault = false,
    this.name,
  });
}

class CardInfo {
  final String? fullName;
  final String? email;
  final String? cardNumber;
  final String? expiryMonth;
  final String? expiryYear;
  final String? cvc;
  final String? country;
  final String? zip;

  CardInfo({
    this.fullName,
    this.email,
    this.cardNumber,
    this.expiryMonth,
    this.expiryYear,
    this.cvc,
    this.country,
    this.zip,
  });

  /// Detect card brand from number prefix (BIN ranges)
  static CardBrand detectBrand(String number) {
    final cleaned = number.replaceAll(RegExp(r'\s'), '');
    if (cleaned.isEmpty) return CardBrand.unknown;

    // Verve: starts with 506099-506198, 650002-650027, 507865-507964
    if (cleaned.length >= 6) {
      final prefix6 = int.tryParse(cleaned.substring(0, 6)) ?? 0;
      if ((prefix6 >= 506099 && prefix6 <= 506198) ||
          (prefix6 >= 650002 && prefix6 <= 650027) ||
          (prefix6 >= 507865 && prefix6 <= 507964)) {
        return CardBrand.verve;
      }
    }

    // Visa: starts with 4
    if (cleaned.startsWith('4')) return CardBrand.visa;

    // Mastercard: starts with 51-55 or 2221-2720
    if (cleaned.length >= 2) {
      final prefix2 = int.tryParse(cleaned.substring(0, 2)) ?? 0;
      if (prefix2 >= 51 && prefix2 <= 55) return CardBrand.mastercard;
    }
    if (cleaned.length >= 4) {
      final prefix4 = int.tryParse(cleaned.substring(0, 4)) ?? 0;
      if (prefix4 >= 2221 && prefix4 <= 2720) return CardBrand.mastercard;
    }

    return CardBrand.unknown;
  }

  /// Format card number with spaces every 4 digits
  static String formatCardNumber(String input) {
    final cleaned = input.replaceAll(RegExp(r'\s'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < cleaned.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(cleaned[i]);
    }
    return buffer.toString();
  }

  /// Mask card number for display: **** **** **** 1234
  static String maskCardNumber(String number) {
    final cleaned = number.replaceAll(RegExp(r'\s'), '');
    if (cleaned.length < 4) return '**** **** **** ****';
    final last4 = cleaned.substring(cleaned.length - 4);
    return '**** **** **** $last4';
  }
}
