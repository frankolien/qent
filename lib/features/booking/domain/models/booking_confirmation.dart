import 'package:flutter/material.dart';

class BookingConfirmation {
  final String bookingId;
  final String customerName;
  final DateTime pickupDate;
  final TimeOfDay pickupTime;
  final DateTime returnDate;
  final TimeOfDay returnTime;
  final String location;
  final String transactionId;
  final double amount;
  final double serviceFee;
  final double totalAmount;
  final String paymentMethod;

  BookingConfirmation({
    required this.bookingId,
    required this.customerName,
    required this.pickupDate,
    required this.pickupTime,
    required this.returnDate,
    required this.returnTime,
    required this.location,
    required this.transactionId,
    required this.amount,
    required this.serviceFee,
    required this.totalAmount,
    required this.paymentMethod,
  });
}

