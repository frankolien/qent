enum PaymentMethodType {
  cash,
  card,
  applePay,
  googlePay,
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
}

