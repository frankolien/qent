import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qent/core/services/api_client.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart';

// ─── Providers ────────────────────────────────────────────

final adminCarsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final resp = await client.get('/admin/cars');
  if (resp.isSuccess) return (resp.body as List).cast<Map<String, dynamic>>();
  throw Exception(resp.errorMessage);
});

final adminUsersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final resp = await client.get('/admin/users');
  if (resp.isSuccess) return (resp.body as List).cast<Map<String, dynamic>>();
  throw Exception(resp.errorMessage);
});

final adminAnalyticsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final resp = await client.get('/admin/analytics');
  if (resp.isSuccess) return resp.body as Map<String, dynamic>;
  throw Exception(resp.errorMessage);
});

// ─── Admin Panel Page ─────────────────────────────────────

class AdminPanelPage extends ConsumerStatefulWidget {
  const AdminPanelPage({super.key});

  @override
  ConsumerState<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends ConsumerState<AdminPanelPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(adminCarsProvider);
    ref.invalidate(adminUsersProvider);
    ref.invalidate(adminAnalyticsProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildAnalyticsBar(),
            _buildTabs(),
            Expanded(
              child: [
                _buildCarsTab(),
                _buildUsersTab(),
                _buildPendingTab(),
              ][_tabController.index],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: const Color(0xFFF2F2F2), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.arrow_back_ios_new, size: 16, color: Color(0xFF1A1A1A)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text('Admin Panel', style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
          ),
          GestureDetector(
            onTap: _refresh,
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: const Color(0xFFF2F2F2), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF1A1A1A)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsBar() {
    final analyticsAsync = ref.watch(adminAnalyticsProvider);
    return analyticsAsync.when(
      data: (data) {
        final formatter = NumberFormat('#,##0', 'en_US');
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            children: [
              _statCard('${data['total_users'] ?? 0}', 'Users'),
              const SizedBox(width: 8),
              _statCard('${data['total_cars'] ?? 0}', 'Cars'),
              const SizedBox(width: 8),
              _statCard('${data['total_bookings'] ?? 0}', 'Bookings'),
              const SizedBox(width: 8),
              _statCard('\u20a6${formatter.format(((data['total_revenue'] as num?)?.toInt() ?? 0))}', 'Revenue'),
            ],
          ),
        );
      },
      loading: () => const SizedBox(height: 70),
      error: (_, __) => const SizedBox(height: 70),
    );
  }

  Widget _statCard(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Text(value, style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
            const SizedBox(height: 2),
            Text(label, style: GoogleFonts.roboto(fontSize: 10, color: Colors.grey[400])),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        height: 44,
        decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(22)),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(22)),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey[600],
          labelStyle: GoogleFonts.roboto(fontSize: 13, fontWeight: FontWeight.w600),
          dividerColor: Colors.transparent,
          tabs: const [Tab(text: 'Cars'), Tab(text: 'Users'), Tab(text: 'Pending')],
        ),
      ),
    );
  }

  // ─── Cars Tab ───────────────────────────────────────────

  Widget _buildCarsTab() {
    final carsAsync = ref.watch(adminCarsProvider);
    return carsAsync.when(
      data: (cars) {
        if (cars.isEmpty) return _empty('No cars');
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: cars.length,
          itemBuilder: (_, i) => _buildCarCard(cars[i]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A1A1A))),
      error: (e, _) => _empty('Failed to load: $e'),
    );
  }

  Widget _buildCarCard(Map<String, dynamic> car) {
    final status = (car['status'] as String? ?? '').toLowerCase();
    final isPending = status == 'pendingapproval';
    final photo = (car['photos'] as List?)?.isNotEmpty == true ? car['photos'][0] : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isPending ? const Color(0xFFFFF3E0) : const Color(0xFFF2F2F2)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: photo != null
                ? CachedNetworkImage(
                    imageUrl: photo,
                    width: 64,
                    height: 50,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _imgPlaceholder(),
                    errorWidget: (_, __, ___) => _imgPlaceholder(),
                  )
                : _imgPlaceholder(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${car['make']} ${car['model']}', style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A))),
                const SizedBox(height: 2),
                Text('Host: ${car['host_name'] ?? 'Unknown'}', style: GoogleFonts.roboto(fontSize: 11, color: Colors.grey[500])),
                const SizedBox(height: 4),
                _statusChip(status),
              ],
            ),
          ),
          if (isPending) ...[
            _actionBtn(Icons.check_rounded, const Color(0xFF2E7D32), () => _approveCar(car['id'])),
            const SizedBox(width: 6),
            _actionBtn(Icons.close_rounded, Colors.red, () => _rejectCar(car['id'])),
          ] else if (status == 'active')
            _actionBtn(Icons.block_rounded, Colors.orange, () => _rejectCar(car['id'])),
        ],
      ),
    );
  }

  // ─── Users Tab ──────────────────────────────────────────

  Widget _buildUsersTab() {
    final usersAsync = ref.watch(adminUsersProvider);
    return usersAsync.when(
      data: (users) {
        if (users.isEmpty) return _empty('No users');
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: users.length,
          itemBuilder: (_, i) => _buildUserCard(users[i]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A1A1A))),
      error: (e, _) => _empty('Failed to load: $e'),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final role = (user['role'] as String? ?? 'Renter');
    final verification = (user['verification_status'] as String? ?? 'Pending').toLowerCase();
    final isVerified = verification == 'verified';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF2F2F2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: const Color(0xFFF2F2F2), borderRadius: BorderRadius.circular(14)),
            child: Center(
              child: Text(
                (user['full_name'] as String? ?? '?')[0].toUpperCase(),
                style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user['full_name'] ?? 'Unknown', style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A))),
                const SizedBox(height: 2),
                Text(user['email'] ?? '', style: GoogleFonts.roboto(fontSize: 11, color: Colors.grey[500])),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _statusChip(role.toLowerCase()),
                    const SizedBox(width: 6),
                    _statusChip(verification),
                  ],
                ),
              ],
            ),
          ),
          if (!isVerified && verification == 'pending')
            _actionBtn(Icons.verified_rounded, const Color(0xFF2E7D32), () => _verifyUser(user['id'])),
        ],
      ),
    );
  }

  // ─── Pending Tab ────────────────────────────────────────

  Widget _buildPendingTab() {
    final carsAsync = ref.watch(adminCarsProvider);
    return carsAsync.when(
      data: (cars) {
        final pending = cars.where((c) => (c['status'] as String? ?? '').toLowerCase() == 'pendingapproval').toList();
        if (pending.isEmpty) {
          return _empty('No pending approvals');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: pending.length,
          itemBuilder: (_, i) => _buildCarCard(pending[i]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A1A1A))),
      error: (e, _) => _empty('Failed to load'),
    );
  }

  // ─── Actions ────────────────────────────────────────────

  Future<void> _approveCar(String carId) async {
    HapticFeedback.mediumImpact();
    final client = ref.read(apiClientProvider);
    final resp = await client.post('/admin/cars/$carId/approve');
    if (resp.isSuccess) {
      _showToast('Car approved');
      ref.invalidate(adminCarsProvider);
      ref.invalidate(adminAnalyticsProvider);
    } else {
      _showToast(resp.errorMessage, isError: true);
    }
  }

  Future<void> _rejectCar(String carId) async {
    HapticFeedback.mediumImpact();
    final client = ref.read(apiClientProvider);
    final resp = await client.post('/admin/cars/$carId/reject');
    if (resp.isSuccess) {
      _showToast('Car rejected');
      ref.invalidate(adminCarsProvider);
    } else {
      _showToast(resp.errorMessage, isError: true);
    }
  }

  Future<void> _verifyUser(String userId) async {
    HapticFeedback.mediumImpact();
    final client = ref.read(apiClientProvider);
    final resp = await client.post('/admin/users/$userId/verify');
    if (resp.isSuccess) {
      _showToast('User verified');
      ref.invalidate(adminUsersProvider);
    } else {
      _showToast(resp.errorMessage, isError: true);
    }
  }

  // ─── Helpers ────────────────────────────────────────────

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  Widget _statusChip(String status) {
    final (bg, text) = switch (status) {
      'active' || 'verified' => (const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
      'pendingapproval' || 'pending' => (const Color(0xFFFFF3E0), const Color(0xFFE65100)),
      'admin' => (const Color(0xFFE3F2FD), const Color(0xFF1565C0)),
      'host' => (const Color(0xFFF5F5F5), const Color(0xFF1A1A1A)),
      'renter' => (const Color(0xFFF5F5F5), const Color(0xFF616161)),
      'rejected' || 'inactive' => (const Color(0xFFFFEBEE), const Color(0xFFC62828)),
      _ => (const Color(0xFFF5F5F5), const Color(0xFF616161)),
    };

    final label = status == 'pendingapproval' ? 'Pending' : status[0].toUpperCase() + status.substring(1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: GoogleFonts.roboto(fontSize: 10, fontWeight: FontWeight.w600, color: text)),
    );
  }

  Widget _imgPlaceholder() {
    return Container(
      width: 64, height: 50,
      decoration: BoxDecoration(color: const Color(0xFFF2F2F2), borderRadius: BorderRadius.circular(12)),
      child: Icon(Icons.directions_car_rounded, color: Colors.grey[400], size: 22),
    );
  }

  Widget _empty(String msg) {
    return Center(child: Text(msg, style: GoogleFonts.roboto(fontSize: 13, color: Colors.grey[400])));
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20, right: 20,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 300),
            builder: (_, val, child) => Opacity(opacity: val, child: Transform.translate(offset: Offset(0, -20 * (1 - val)), child: child)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isError ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: Row(
                children: [
                  Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(message, style: GoogleFonts.roboto(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), () => entry.remove());
  }
}
