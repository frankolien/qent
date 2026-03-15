import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qent/core/services/api_client.dart';
import 'package:qent/features/trips/presentation/pages/trip_detail_page.dart';

class TripBooking {
  final String id;
  final String carId;
  final String renterId;
  final String hostId;
  final String carName;
  final String? carPhoto;
  final String? carLocation;
  final String startDate;
  final String endDate;
  final int totalDays;
  final double totalAmount;
  final double pricePerDay;
  final String status;
  final String createdAt;

  TripBooking({
    required this.id,
    required this.carId,
    required this.renterId,
    required this.hostId,
    required this.carName,
    this.carPhoto,
    this.carLocation,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.totalAmount,
    required this.pricePerDay,
    required this.status,
    required this.createdAt,
  });

  factory TripBooking.fromJson(Map<String, dynamic> json) {
    return TripBooking(
      id: json['id'] ?? '',
      carId: json['car_id'] ?? '',
      renterId: json['renter_id'] ?? '',
      hostId: json['host_id'] ?? '',
      carName: json['car_name'] ?? 'Unknown Car',
      carPhoto: json['car_photo'],
      carLocation: json['car_location'],
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
      totalDays: json['total_days'] ?? 0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      pricePerDay: (json['price_per_day'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'pending',
      createdAt: json['created_at'] ?? '',
    );
  }

  bool get isUpcoming =>
      ['pending', 'approved', 'confirmed'].contains(status);
  bool get isActive => status == 'active';
  bool get isPast => ['completed', 'cancelled', 'rejected'].contains(status);
}

class TripsPage extends StatefulWidget {
  const TripsPage({super.key});

  @override
  State<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends State<TripsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<TripBooking> _allTrips = [];
  bool _isLoading = true;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchTrips();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _fetchTrips(silent: true);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchTrips({bool silent = false}) async {
    if (!silent) {
      setState(() { _isLoading = true; _error = null; });
    }
    try {
      final response = await ApiClient().get('/bookings/mine');
      if (response.isSuccess && mounted) {
        final list = response.body as List;
        setState(() {
          _allTrips = list
              .map((e) => TripBooking.fromJson(e as Map<String, dynamic>))
              .toList();
          _isLoading = false;
        });
      } else if (mounted && !silent) {
        setState(() { _error = response.errorMessage; _isLoading = false; });
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() { _error = e.toString(); _isLoading = false; });
      }
    }
  }

  List<TripBooking> _upcoming() =>
      _allTrips.where((t) => t.isUpcoming).toList();
  List<TripBooking> _active() =>
      _allTrips.where((t) => t.isActive).toList();
  List<TripBooking> _past() =>
      _allTrips.where((t) => t.isPast).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Text(
                'Trips',
                style: GoogleFonts.roboto(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1A1A1A),
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TabBar(
              controller: _tabController,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey[400],
              labelStyle: GoogleFonts.roboto(fontSize: 15, fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.roboto(fontSize: 15, fontWeight: FontWeight.w500),
              indicatorColor: Colors.black,
              indicatorWeight: 2.5,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              tabs: const [
                Tab(text: 'Upcoming'),
                Tab(text: 'Active'),
                Tab(text: 'Past'),
              ],
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A1A1A)))
                  : _error != null
                      ? _buildError()
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildTripList(_upcoming(), 0),
                            _buildTripList(_active(), 1),
                            _buildTripList(_past(), 2),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Failed to load trips', style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _fetchTrips,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('Retry', style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripList(List<TripBooking> trips, int tabIndex) {
    if (trips.isEmpty) return _buildEmpty(tabIndex);
    return RefreshIndicator(
      onRefresh: _fetchTrips,
      color: const Color(0xFF1A1A1A),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.all(20),
        itemCount: trips.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (_, i) => _buildTripCard(trips[i]),
      ),
    );
  }

  Widget _buildEmpty(int tabIndex) {
    final titles = ['No upcoming trips', 'No active trips', 'No past trips'];
    final subtitles = [
      'When you book a car, it will show up here',
      'Your active rentals will appear here',
      'Completed and cancelled trips appear here',
    ];
    final icons = [Icons.calendar_today_rounded, Icons.directions_car_rounded, Icons.history_rounded];
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icons[tabIndex], size: 56, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(titles[tabIndex], style: GoogleFonts.roboto(fontSize: 17, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
          const SizedBox(height: 6),
          Text(subtitles[tabIndex], style: GoogleFonts.roboto(fontSize: 14, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildTripCard(TripBooking trip) {
    final statusInfo = _statusStyle(trip.status);
    final dateFormat = DateFormat('d MMM');
    final formatter = NumberFormat('#,##0', 'en_US');

    String dates = '';
    try {
      final s = DateTime.parse(trip.startDate);
      final e = DateTime.parse(trip.endDate);
      dates = '${dateFormat.format(s)} - ${dateFormat.format(e)}';
    } catch (_) {
      dates = trip.startDate;
    }

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TripDetailPage(trip: trip)),
        );
        _fetchTrips(silent: true);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Car image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: trip.carPhoto != null
                  ? Image.network(
                      trip.carPhoto!,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildImgPlaceholder(),
                    )
                  : _buildImgPlaceholder(),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          trip.carName,
                          style: GoogleFonts.roboto(fontSize: 17, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusInfo.bgColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          statusInfo.label,
                          style: GoogleFonts.roboto(fontSize: 12, fontWeight: FontWeight.w600, color: statusInfo.textColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 6),
                      Text(dates, style: GoogleFonts.roboto(fontSize: 13, color: Colors.grey[600])),
                      const SizedBox(width: 16),
                      Icon(Icons.schedule_rounded, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text('${trip.totalDays} day${trip.totalDays == 1 ? '' : 's'}', style: GoogleFonts.roboto(fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),
                  if (trip.carLocation != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            trip.carLocation!,
                            style: GoogleFonts.roboto(fontSize: 13, color: Colors.grey[600]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '\u20a6${formatter.format(trip.totalAmount.toInt())}',
                        style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)),
                      ),
                      Row(
                        children: [
                          Text('View details', style: GoogleFonts.roboto(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey[500])),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey[500]),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImgPlaceholder() {
    return Container(
      height: 160,
      width: double.infinity,
      color: Colors.grey[100],
      child: Icon(Icons.directions_car_rounded, size: 48, color: Colors.grey[300]),
    );
  }

  ({String label, Color bgColor, Color textColor}) _statusStyle(String status) {
    return switch (status) {
      'pending' => (label: 'Awaiting Host', bgColor: const Color(0xFFFFF3E0), textColor: const Color(0xFFE65100)),
      'approved' => (label: 'Approved', bgColor: const Color(0xFFE3F2FD), textColor: const Color(0xFF1565C0)),
      'confirmed' => (label: 'Confirmed', bgColor: const Color(0xFFE8F5E9), textColor: const Color(0xFF2E7D32)),
      'active' => (label: 'In Progress', bgColor: const Color(0xFFE8F5E9), textColor: const Color(0xFF2E7D32)),
      'completed' => (label: 'Completed', bgColor: const Color(0xFFF5F5F5), textColor: const Color(0xFF616161)),
      'cancelled' => (label: 'Cancelled', bgColor: const Color(0xFFFFEBEE), textColor: const Color(0xFFC62828)),
      'rejected' => (label: 'Declined', bgColor: const Color(0xFFFFEBEE), textColor: const Color(0xFFC62828)),
      _ => (label: status, bgColor: Colors.grey[100]!, textColor: Colors.grey[600]!),
    };
  }
}
