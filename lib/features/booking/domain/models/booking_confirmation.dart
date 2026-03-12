import 'package:flutter/material.dart';

/// Response from POST /api/bookings — maps to the Rust Booking struct
class BookingResponse {
  final String id;
  final String carId;
  final String renterId;
  final String hostId;
  final String startDate;
  final String endDate;
  final int totalDays;
  final double pricePerDay;
  final double subtotal;
  final String? protectionPlanId;
  final double protectionFee;
  final double serviceFee;
  final double totalAmount;
  final String status;
  final String? cancellationReason;
  final String createdAt;
  final String updatedAt;

  BookingResponse({
    required this.id,
    required this.carId,
    required this.renterId,
    required this.hostId,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.pricePerDay,
    required this.subtotal,
    this.protectionPlanId,
    required this.protectionFee,
    required this.serviceFee,
    required this.totalAmount,
    required this.status,
    this.cancellationReason,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BookingResponse.fromJson(Map<String, dynamic> json) {
    return BookingResponse(
      id: json['id'] as String,
      carId: json['car_id'] as String,
      renterId: json['renter_id'] as String,
      hostId: json['host_id'] as String,
      startDate: json['start_date'] as String,
      endDate: json['end_date'] as String,
      totalDays: json['total_days'] as int,
      pricePerDay: (json['price_per_day'] as num).toDouble(),
      subtotal: (json['subtotal'] as num).toDouble(),
      protectionPlanId: json['protection_plan_id'] as String?,
      protectionFee: (json['protection_fee'] as num).toDouble(),
      serviceFee: (json['service_fee'] as num).toDouble(),
      totalAmount: (json['total_amount'] as num).toDouble(),
      status: json['status'] as String,
      cancellationReason: json['cancellation_reason'] as String?,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }
}

/// Response from POST /api/payments/initiate
class PaymentInitResponse {
  final String authorizationUrl;
  final String reference;

  PaymentInitResponse({
    required this.authorizationUrl,
    required this.reference,
  });

  factory PaymentInitResponse.fromJson(Map<String, dynamic> json) {
    return PaymentInitResponse(
      authorizationUrl: json['authorization_url'] as String,
      reference: json['reference'] as String,
    );
  }
}

/// Carries all data through the booking flow (Details → Payment → Confirm → Success)
class BookingConfirmation {
  final String bookingId;
  final String customerName;
  final String email;
  final DateTime pickupDate;
  final TimeOfDay pickupTime;
  final DateTime returnDate;
  final TimeOfDay returnTime;
  final String location;
  final String transactionId;
  final double amount;
  final double serviceFee;
  final double protectionFee;
  final double totalAmount;
  final String paymentMethod;
  final String? paymentReference;

  BookingConfirmation({
    required this.bookingId,
    required this.customerName,
    this.email = '',
    required this.pickupDate,
    required this.pickupTime,
    required this.returnDate,
    required this.returnTime,
    required this.location,
    this.transactionId = '',
    required this.amount,
    required this.serviceFee,
    this.protectionFee = 0.0,
    required this.totalAmount,
    required this.paymentMethod,
    this.paymentReference,
  });

  BookingConfirmation copyWith({
    String? bookingId,
    String? customerName,
    String? email,
    DateTime? pickupDate,
    TimeOfDay? pickupTime,
    DateTime? returnDate,
    TimeOfDay? returnTime,
    String? location,
    String? transactionId,
    double? amount,
    double? serviceFee,
    double? protectionFee,
    double? totalAmount,
    String? paymentMethod,
    String? paymentReference,
  }) {
    return BookingConfirmation(
      bookingId: bookingId ?? this.bookingId,
      customerName: customerName ?? this.customerName,
      email: email ?? this.email,
      pickupDate: pickupDate ?? this.pickupDate,
      pickupTime: pickupTime ?? this.pickupTime,
      returnDate: returnDate ?? this.returnDate,
      returnTime: returnTime ?? this.returnTime,
      location: location ?? this.location,
      transactionId: transactionId ?? this.transactionId,
      amount: amount ?? this.amount,
      serviceFee: serviceFee ?? this.serviceFee,
      protectionFee: protectionFee ?? this.protectionFee,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentReference: paymentReference ?? this.paymentReference,
    );
  }
}
