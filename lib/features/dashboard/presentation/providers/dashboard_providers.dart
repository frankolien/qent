import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart';

class HostStats {
  final int totalListings;
  final int activeListings;
  final int totalViews;
  final int totalBookings;
  final double totalEarnings;
  final double thisMonthEarnings;
  final double averageRating;
  final double walletBalance;

  HostStats({
    required this.totalListings,
    required this.activeListings,
    required this.totalViews,
    required this.totalBookings,
    required this.totalEarnings,
    required this.thisMonthEarnings,
    required this.averageRating,
    required this.walletBalance,
  });

  factory HostStats.fromJson(Map<String, dynamic> json) {
    return HostStats(
      totalListings: (json['total_listings'] as num?)?.toInt() ?? 0,
      activeListings: (json['active_listings'] as num?)?.toInt() ?? 0,
      totalViews: (json['total_views'] as num?)?.toInt() ?? 0,
      totalBookings: (json['total_bookings'] as num?)?.toInt() ?? 0,
      totalEarnings: (json['total_earnings'] as num?)?.toDouble() ?? 0.0,
      thisMonthEarnings: (json['this_month_earnings'] as num?)?.toDouble() ?? 0.0,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0.0,
      walletBalance: (json['wallet_balance'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ListingSummary {
  final String id;
  final String make;
  final String model;
  final int year;
  final String photo;
  final double pricePerDay;
  final String status;
  final int viewsCount;
  final double rating;
  final int tripCount;

  ListingSummary({
    required this.id,
    required this.make,
    required this.model,
    required this.year,
    required this.photo,
    required this.pricePerDay,
    required this.status,
    required this.viewsCount,
    required this.rating,
    required this.tripCount,
  });

  factory ListingSummary.fromJson(Map<String, dynamic> json) {
    return ListingSummary(
      id: json['id'] ?? '',
      make: json['make'] ?? '',
      model: json['model'] ?? '',
      year: (json['year'] as num?)?.toInt() ?? 0,
      photo: json['photo'] ?? '',
      pricePerDay: (json['price_per_day'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'active',
      viewsCount: (json['views_count'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      tripCount: (json['trip_count'] as num?)?.toInt() ?? 0,
    );
  }
}

final hostStatsProvider = FutureProvider<HostStats>((ref) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.get('/dashboard/stats');
  if (response.isSuccess) {
    return HostStats.fromJson(response.body);
  }
  throw Exception(response.errorMessage);
});

class PendingBooking {
  final String id;
  final String carName;
  final String? carPhoto;
  final String? carLocation;
  final String startDate;
  final String endDate;
  final int totalDays;
  final double totalAmount;
  final String renterName;
  final String renterId;

  PendingBooking({
    required this.id,
    required this.carName,
    this.carPhoto,
    this.carLocation,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.totalAmount,
    required this.renterName,
    required this.renterId,
  });

  factory PendingBooking.fromJson(Map<String, dynamic> json) {
    return PendingBooking(
      id: json['id'] ?? '',
      carName: json['car_name'] ?? 'Unknown Car',
      carPhoto: json['car_photo'],
      carLocation: json['car_location'],
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
      totalDays: (json['total_days'] as num?)?.toInt() ?? 0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      renterName: json['renter_name'] ?? 'Unknown',
      renterId: json['renter_id'] ?? '',
    );
  }
}

final hostPendingBookingsProvider = FutureProvider<List<PendingBooking>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.get('/bookings/host/pending');
  if (response.isSuccess) {
    final list = response.body as List;
    return list.map((e) => PendingBooking.fromJson(e)).toList();
  }
  throw Exception(response.errorMessage);
});

final hostListingsProvider = FutureProvider<List<ListingSummary>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.get('/dashboard/listings');
  if (response.isSuccess) {
    final list = response.body as List;
    return list.map((e) => ListingSummary.fromJson(e)).toList();
  }
  throw Exception(response.errorMessage);
});
