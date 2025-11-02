import 'package:flutter/material.dart';
import 'package:qent/features/home/domain/models/car.dart';

class CarDetail extends Car {
  final String description;
  final List<String> imageUrls;
  final Host host;
  final List<CarFeature> features;
  final List<Review> reviews;
  final int totalReviews;

  CarDetail({
    required super.id,
    required super.name,
    required super.brand,
    required super.imageUrl,
    required super.rating,
    required super.location,
    required super.seats,
    required super.pricePerDay,
    super.isFavorite,
    required this.description,
    required this.imageUrls,
    required this.host,
    required this.features,
    required this.reviews,
    this.totalReviews = 0,
  }) : super();

  CarDetail.fromCar({
    required Car car,
    required this.description,
    required this.imageUrls,
    required this.host,
    required this.features,
    required this.reviews,
    this.totalReviews = 0,
  }) : super(
          id: car.id,
          name: car.name,
          brand: car.brand,
          imageUrl: car.imageUrl,
          rating: car.rating,
          location: car.location,
          seats: car.seats,
          pricePerDay: car.pricePerDay,
          isFavorite: car.isFavorite,
        );
}

class Host {
  final String id;
  final String name;
  final String profileImageUrl;
  final bool isVerified;

  Host({
    required this.id,
    required this.name,
    required this.profileImageUrl,
    this.isVerified = false,
  });
}

class CarFeature {
  final String id;
  final String label;
  final String value;
  final IconData icon;

  CarFeature({
    required this.id,
    required this.label,
    required this.value,
    required this.icon,
  });
}

class Review {
  final String id;
  final String userName;
  final String userImageUrl;
  final double rating;
  final String comment;
  final DateTime date;

  Review({
    required this.id,
    required this.userName,
    required this.userImageUrl,
    required this.rating,
    required this.comment,
    required this.date,
  });
}

