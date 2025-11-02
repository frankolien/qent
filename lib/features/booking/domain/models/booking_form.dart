import 'package:flutter/material.dart';

class BookingForm {
  final bool bookWithDriver;
  final String? fullName;
  final String? email;
  final String? contact;
  final Gender? gender;
  final RentalDuration? rentalDuration;
  final DateTime? pickupDate;
  final DateTime? returnDate;
  final TimeOfDay? pickupTime;
  final TimeOfDay? returnTime;
  final String? carLocation;
  final double totalPrice;

  BookingForm({
    this.bookWithDriver = false,
    this.fullName,
    this.email,
    this.contact,
    this.gender,
    this.rentalDuration,
    this.pickupDate,
    this.returnDate,
    this.pickupTime,
    this.returnTime,
    this.carLocation,
    this.totalPrice = 0.0,
  });

  BookingForm copyWith({
    bool? bookWithDriver,
    String? fullName,
    String? email,
    String? contact,
    Gender? gender,
    RentalDuration? rentalDuration,
    DateTime? pickupDate,
    DateTime? returnDate,
    TimeOfDay? pickupTime,
    TimeOfDay? returnTime,
    String? carLocation,
    double? totalPrice,
  }) {
    return BookingForm(
      bookWithDriver: bookWithDriver ?? this.bookWithDriver,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      contact: contact ?? this.contact,
      gender: gender ?? this.gender,
      rentalDuration: rentalDuration ?? this.rentalDuration,
      pickupDate: pickupDate ?? this.pickupDate,
      returnDate: returnDate ?? this.returnDate,
      pickupTime: pickupTime ?? this.pickupTime,
      returnTime: returnTime ?? this.returnTime,
      carLocation: carLocation ?? this.carLocation,
      totalPrice: totalPrice ?? this.totalPrice,
    );
  }
}

enum Gender {
  male,
  female,
  others,
}

enum RentalDuration {
  hour,
  day,
  weekly,
  monthly,
}

