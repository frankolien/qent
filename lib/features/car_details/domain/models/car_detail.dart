import 'package:flutter/material.dart';
import 'package:qent/features/home/domain/models/car.dart';

class CarDetail extends Car {
  final String detailDescription;
  final List<String> imageUrls;
  final Host host;
  final List<CarFeature> carFeatures;
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
    super.description,
    super.photos,
    super.features,
    super.color,
    super.year,
    super.hostId,
    super.tripCount,
    required this.detailDescription,
    required this.imageUrls,
    required this.host,
    required this.carFeatures,
    required this.reviews,
    this.totalReviews = 0,
  }) : super();

  CarDetail.fromCar({
    required Car car,
    required this.detailDescription,
    required this.imageUrls,
    required this.host,
    required this.carFeatures,
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
          description: car.description,
          photos: car.photos,
          features: car.features,
          color: car.color,
          year: car.year,
          hostId: car.hostId,
          hostName: car.hostName,
          tripCount: car.tripCount,
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
  final IconData? icon;
  final String? assetImage;

  CarFeature({
    required this.id,
    required this.label,
    required this.value,
    this.icon,
    this.assetImage,
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

  factory Review.fromBackendJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'].toString(),
      userName: (json['reviewer_name'] ?? 'User').toString(),
      userImageUrl: (json['reviewer_photo_url'] ?? '').toString(),
      rating: (json['rating'] is num) ? (json['rating'] as num).toDouble() : 0.0,
      comment: (json['comment'] ?? '').toString(),
      date: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}
