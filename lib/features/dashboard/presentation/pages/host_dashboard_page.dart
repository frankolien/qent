import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qent/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:qent/features/dashboard/presentation/pages/add_listing_page.dart';
import 'package:qent/core/widgets/animated_loading.dart';
import 'package:qent/core/widgets/profile_image_widget.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart';

class HostDashboardPage extends ConsumerWidget {
  const HostDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(hostStatsProvider);
    final listingsAsync = ref.watch(hostListingsProvider);
    final pendingAsync = ref.watch(hostPendingBookingsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: SafeArea(
        child: statsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFF1A1A1A), strokeWidth: 2),
          ),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off_rounded, size: 40, color: Colors.grey[300]),
                const SizedBox(height: 8),
                Text(
                  'Failed to load',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    ref.invalidate(hostStatsProvider);
                    ref.invalidate(hostListingsProvider);
                    ref.invalidate(hostPendingBookingsProvider);
                  },
                  child: const Text(
                    'Retry',
                    style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          data: (stats) => CarPullToRefresh(
            onRefresh: () async {
              ref.invalidate(hostStatsProvider);
              ref.invalidate(hostListingsProvider);
              ref.invalidate(hostPendingBookingsProvider);
              await ref.read(hostStatsProvider.future);
            },
            child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).maybePop(),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F2F2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new, size: 16, color: Color(0xFF1A1A1A)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'Dashboard',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          ref.invalidate(hostStatsProvider);
                          ref.invalidate(hostListingsProvider);
                        },
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F2F2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF1A1A1A)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Balance card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Wallet Balance',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF4CAF50),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Active',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white.withValues(alpha: 0.6),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '\₦${_formatAmount(stats.walletBalance)}',
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'This month',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '\$${_formatAmount(stats.thisMonthEarnings)}',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 36,
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'All time',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white.withValues(alpha: 0.4),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '\$${_formatAmount(stats.totalEarnings)}',
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Stats row
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    children: [
                      _buildStatTile('${stats.totalViews}', 'Views'),
                      const SizedBox(width: 10),
                      _buildStatTile('${stats.activeListings}', 'Active'),
                      const SizedBox(width: 10),
                      _buildStatTile('${stats.totalBookings}', 'Bookings'),
                      const SizedBox(width: 10),
                      _buildStatTile(
                        stats.averageRating > 0 ? stats.averageRating.toStringAsFixed(1) : '—',
                        'Rating',
                      ),
                    ],
                  ),
                ),
              ),

              // Pending Bookings
              SliverToBoxAdapter(
                child: _buildPendingBookingsSection(pendingAsync, ref),
              ),

              // Listings header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'My Listings',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${stats.totalListings} vehicles',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddListingPage())),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add, size: 16, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'Add',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Listings
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  child: _buildListingsSection(listingsAsync),
                ),
              ),

              // Bottom spacing
              const SliverToBoxAdapter(
                child: SizedBox(height: 40),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingBookingsSection(AsyncValue<List<PendingBooking>> pendingAsync, WidgetRef ref) {
    return pendingAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (bookings) {
        if (bookings.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF385C),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Pending Requests',
                    style: GoogleFonts.roboto(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF385C),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${bookings.length}',
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...bookings.map((b) => _buildPendingBookingCard(b, ref)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPendingBookingCard(PendingBooking booking, WidgetRef ref) {
    final dateFormat = DateFormat('d MMM');
    final formatter = NumberFormat('#,##0', 'en_US');

    String dates = '';
    try {
      final s = DateTime.parse(booking.startDate);
      final e = DateTime.parse(booking.endDate);
      dates = '${dateFormat.format(s)} - ${dateFormat.format(e)}';
    } catch (_) {
      dates = booking.startDate;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFF3E0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProfileImageWidget(userId: booking.renterId, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.renterName,
                      style: GoogleFonts.roboto(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      booking.carName,
                      style: GoogleFonts.roboto(
                        fontSize: 13,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '\u20a6${formatter.format(booking.totalAmount.toInt())}',
                style: GoogleFonts.roboto(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 13, color: Colors.grey[400]),
              const SizedBox(width: 6),
              Text(dates, style: GoogleFonts.roboto(fontSize: 13, color: Colors.grey[600])),
              const SizedBox(width: 16),
              Icon(Icons.schedule_rounded, size: 13, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(
                '${booking.totalDays} day${booking.totalDays == 1 ? '' : 's'}',
                style: GoogleFonts.roboto(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
          if (booking.carLocation != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 13, color: Colors.grey[400]),
                const SizedBox(width: 6),
                Text(
                  booking.carLocation!,
                  style: GoogleFonts.roboto(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _handleBookingAction(ref, booking.id, 'reject'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'Decline',
                        style: GoogleFonts.roboto(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _handleBookingAction(ref, booking.id, 'approve'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'Accept',
                        style: GoogleFonts.roboto(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleBookingAction(WidgetRef ref, String bookingId, String action) async {
    HapticFeedback.mediumImpact();
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.post(
        '/bookings/$bookingId/action',
        body: {'action': action},
      );
      if (response.isSuccess) {
        ref.invalidate(hostPendingBookingsProvider);
        ref.invalidate(hostStatsProvider);
      }
    } catch (_) {}
  }

  String _formatAmount(double amount) {
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(amount % 1000 == 0 ? 0 : 1)}k';
    }
    return amount.toStringAsFixed(amount == amount.truncateToDouble() ? 0 : 2);
  }

  Widget _buildStatTile(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListingsSection(AsyncValue<List<ListingSummary>> listingsAsync) {
    return listingsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF1A1A1A), strokeWidth: 2),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Text('Failed to load', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
        ),
      ),
      data: (listings) {
        if (listings.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.directions_car_rounded, size: 28, color: Colors.grey[400]),
                ),
                const SizedBox(height: 14),
                const Text(
                  'No listings yet',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add your first vehicle to start earning',
                  style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Column(
            children: listings.map((l) => _buildListingCard(l)).toList(),
          ),
        );
      },
    );
  }

  Widget _buildListingCard(ListingSummary listing) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: listing.photo.isNotEmpty
                ? Image.network(
                    listing.photo,
                    width: 72,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPhotoPlaceholder(),
                  )
                : _buildPhotoPlaceholder(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${listing.make} ${listing.model}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: listing.status == 'active'
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFF2F2F2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        listing.status[0].toUpperCase() + listing.status.substring(1),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: listing.status == 'active'
                              ? const Color(0xFF2E7D32)
                              : Colors.grey[500],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '\₦${listing.pricePerDay.toStringAsFixed(0)}/day',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.remove_red_eye_outlined, size: 13, color: Colors.grey[350]),
                    const SizedBox(width: 3),
                    Text(
                      '${listing.viewsCount}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    ),
                    const SizedBox(width: 10),
                    if (listing.rating > 0) ...[
                      Icon(Icons.star_rounded, size: 13, color: Colors.grey[350]),
                      const SizedBox(width: 2),
                      Text(
                        listing.rating.toStringAsFixed(1),
                        style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Text(
                      '${listing.tripCount} trips',
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoPlaceholder() {
    return Container(
      width: 72,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(Icons.directions_car_rounded, color: Colors.grey[400], size: 24),
    );
  }
}
