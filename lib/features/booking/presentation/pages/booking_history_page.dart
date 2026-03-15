import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qent/core/services/api_client.dart';

class BookingHistory {
  final String id;
  final String carId;
  final String carName;
  final String? carPhoto;
  final String? carLocation;
  final String startDate;
  final String endDate;
  final int totalDays;
  final double totalAmount;
  final String status;
  final String createdAt;

  BookingHistory({
    required this.id,
    required this.carId,
    required this.carName,
    this.carPhoto,
    this.carLocation,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
  });

  factory BookingHistory.fromJson(Map<String, dynamic> json) {
    return BookingHistory(
      id: json['id'] ?? '',
      carId: json['car_id'] ?? '',
      carName: json['car_name'] ?? 'Unknown Car',
      carPhoto: json['car_photo'],
      carLocation: json['car_location'],
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
      totalDays: json['total_days'] ?? 0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'pending',
      createdAt: json['created_at'] ?? '',
    );
  }
}

class BookingHistoryPage extends StatefulWidget {
  const BookingHistoryPage({super.key});

  @override
  State<BookingHistoryPage> createState() => _BookingHistoryPageState();
}

class _BookingHistoryPageState extends State<BookingHistoryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<BookingHistory> _allBookings = [];
  bool _isLoading = true;
  String? _error;

  final _tabs = const ['All', 'Active', 'Completed', 'Cancelled'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _fetchBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchBookings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await ApiClient().get('/bookings/mine');
      debugPrint('[BookingHistory] Response: ${response.body}');
      if (response.isSuccess && mounted) {
        final list = response.body as List;
        setState(() {
          _allBookings = list
              .map((e) => BookingHistory.fromJson(e as Map<String, dynamic>))
              .toList();
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _error = response.errorMessage;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<BookingHistory> _filteredBookings(int tabIndex) {
    if (tabIndex == 0) return _allBookings;
    final filter = switch (tabIndex) {
      1 => ['pending', 'approved', 'confirmed', 'active'],
      2 => ['completed'],
      3 => ['cancelled', 'rejected'],
      _ => <String>[],
    };
    return _allBookings.where((b) => filter.contains(b.status)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey[300]!, width: 1),
                ),
                child: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.black),
              ),
            ),
          ),
        ),
        centerTitle: true,
        title: Text(
          'Booking History',
          style: GoogleFonts.roboto(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(
            children: [
              Container(color: Colors.grey[200], height: 1),
              TabBar(
                controller: _tabController,
                labelColor: Colors.black,
                unselectedLabelColor: Colors.grey[400],
                labelStyle: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w600),
                unselectedLabelStyle: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w500),
                indicatorColor: Colors.black,
                indicatorWeight: 2.5,
                tabs: _tabs.map((t) => Tab(text: t)).toList(),
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A1A1A)))
          : _error != null
              ? _buildErrorState()
              : TabBarView(
                  controller: _tabController,
                  children: List.generate(_tabs.length, (i) {
                    final bookings = _filteredBookings(i);
                    if (bookings.isEmpty) return _buildEmptyState(i);
                    return RefreshIndicator(
                      onRefresh: _fetchBookings,
                      color: const Color(0xFF1A1A1A),
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.all(20),
                        itemCount: bookings.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (_, idx) => _buildBookingCard(bookings[idx]),
                      ),
                    );
                  }),
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.roboto(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _fetchBookings,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Retry',
                  style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(int tabIndex) {
    final messages = [
      'No bookings yet',
      'No active bookings',
      'No completed trips',
      'No cancelled bookings',
    ];
    final subtitles = [
      'Your booking history will appear here',
      'You have no ongoing or upcoming bookings',
      'Completed trips will show up here',
      'Great — no cancellations!',
    ];
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.directions_car_outlined, size: 56, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            messages[tabIndex],
            style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black),
          ),
          const SizedBox(height: 6),
          Text(
            subtitles[tabIndex],
            style: GoogleFonts.roboto(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(BookingHistory booking) {
    final statusInfo = _statusInfo(booking.status);
    final formatter = NumberFormat('#,##0', 'en_US');
    final dateFormat = DateFormat('d MMM yy');

    String formattedDates = '';
    try {
      final start = DateTime.parse(booking.startDate);
      final end = DateTime.parse(booking.endDate);
      formattedDates = '${dateFormat.format(start)} - ${dateFormat.format(end)}';
    } catch (_) {
      formattedDates = '${booking.startDate} - ${booking.endDate}';
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Car image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: booking.carPhoto != null
                  ? Image.network(
                      booking.carPhoto!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
                    )
                  : _buildPlaceholderImage(),
            ),
            const SizedBox(width: 14),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          booking.carName,
                          style: GoogleFonts.roboto(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A1A1A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusInfo.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          statusInfo.label,
                          style: GoogleFonts.roboto(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusInfo.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 13, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        formattedDates,
                        style: GoogleFonts.roboto(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  if (booking.carLocation != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 13, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            booking.carLocation!,
                            style: GoogleFonts.roboto(fontSize: 12, color: Colors.grey[500]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${booking.totalDays} day${booking.totalDays == 1 ? '' : 's'}',
                        style: GoogleFonts.roboto(fontSize: 12, color: Colors.grey[500]),
                      ),
                      Text(
                        '\u20a6${formatter.format(booking.totalAmount.toInt())}',
                        style: GoogleFonts.roboto(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A1A1A),
                        ),
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

  Widget _buildPlaceholderImage() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.directions_car_rounded, size: 32, color: Colors.grey[400]),
    );
  }

  ({String label, Color color}) _statusInfo(String status) {
    return switch (status) {
      'pending' => (label: 'Pending', color: const Color(0xFFFF9800)),
      'approved' => (label: 'Approved', color: const Color(0xFF2196F3)),
      'confirmed' => (label: 'Confirmed', color: const Color(0xFF2196F3)),
      'active' => (label: 'Active', color: const Color(0xFF4CAF50)),
      'completed' => (label: 'Completed', color: const Color(0xFF4CAF50)),
      'cancelled' => (label: 'Cancelled', color: const Color(0xFFF44336)),
      'rejected' => (label: 'Rejected', color: const Color(0xFFF44336)),
      _ => (label: status, color: Colors.grey),
    };
  }
}
