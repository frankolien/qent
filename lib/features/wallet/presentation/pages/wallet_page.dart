import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart';
import 'package:qent/core/theme/app_theme.dart';

// ─── Providers ────────────────────────────────────────────────

final walletBalanceProvider = FutureProvider<double>((ref) async {
  final client = ref.watch(apiClientProvider);
  final resp = await client.get('/payments/wallet');
  if (resp.isSuccess) return (resp.body['balance'] as num?)?.toDouble() ?? 0.0;
  throw Exception(resp.errorMessage);
});

final earningsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final resp = await client.get('/payments/earnings');
  if (resp.isSuccess) return resp.body as Map<String, dynamic>;
  throw Exception(resp.errorMessage);
});

final walletTransactionsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final resp = await client.get('/payments/wallet/transactions');
  if (resp.isSuccess) return (resp.body as List).cast<Map<String, dynamic>>();
  throw Exception(resp.errorMessage);
});

final banksProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final resp = await client.get('/payments/banks', auth: false);
  if (resp.isSuccess) return (resp.body as List).cast<Map<String, dynamic>>();
  throw Exception(resp.errorMessage);
});

// ─── Page ─────────────────────────────────────────────────────

class WalletPage extends ConsumerStatefulWidget {
  const WalletPage({super.key});

  @override
  ConsumerState<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends ConsumerState<WalletPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formatter = NumberFormat('#,##0', 'en_US');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(walletBalanceProvider);
    ref.invalidate(earningsProvider);
    ref.invalidate(walletTransactionsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final earningsAsync = ref.watch(earningsProvider);

    

    return Scaffold(
      backgroundColor: context.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  _refresh();
                  await ref.read(earningsProvider.future);
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  child: Column(
                    children: [
                      earningsAsync.when(
                        data: (data) => _buildBalanceCard(data),
                        loading: () => _buildBalanceCardSkeleton(),
                        error: (_, __) => _buildBalanceCardSkeleton(),
                      ),
                      const SizedBox(height: 20),
                      earningsAsync.when(
                        data: (data) => _buildStatsRow(data),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 24),
                      _buildTabSection(),
                    ],
                  ),
                ),
              ),
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
              decoration: BoxDecoration(color: context.bgSecondary, borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.arrow_back_ios_new, size: 16, color: context.textPrimary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text('Wallet & Earnings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.textPrimary)),
          ),
          GestureDetector(
            onTap: _refresh,
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: context.bgSecondary, borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.refresh_rounded, size: 20, color: context.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(Map<String, dynamic> data) {
    final balance = (data['wallet_balance'] as num?)?.toDouble() ?? 0.0;
    final totalEarned = (data['total_earned'] as num?)?.toDouble() ?? 0.0;
    final thisMonth = (data['this_month'] as num?)?.toDouble() ?? 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Available Balance', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.5))),
                GestureDetector(
                  onTap: () => _showWithdrawSheet(balance),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: context.isDark ? context.accent : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Withdraw', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.isDark ? Colors.black : const Color(0xFF1A1A1A))),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('\u20a6${_formatter.format(balance.toInt())}',
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -1)),
            const SizedBox(height: 20),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildBalanceStat('This Month', '\u20a6${_formatter.format(thisMonth.toInt())}')),
                Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.08)),
                Expanded(child: Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: _buildBalanceStat('All Time', '\u20a6${_formatter.format(totalEarned.toInt())}'),
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
      ],
    );
  }

  Widget _buildBalanceCardSkeleton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        height: 200,
        decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(20)),
        child: const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
      ),
    );
  }

  Widget _buildStatsRow(Map<String, dynamic> data) {
    final pending = (data['pending_earnings'] as num?)?.toDouble() ?? 0.0;
    final completed = (data['completed_trips'] as num?)?.toInt() ?? 0;
    final fee = (data['platform_fee_percent'] as num?)?.toInt() ?? 15;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildStatTile('\u20a6${_formatter.format(pending.toInt())}', 'Pending'),
          const SizedBox(width: 10),
          _buildStatTile('$completed', 'Trips'),
          const SizedBox(width: 10),
          _buildStatTile('$fee%', 'Platform Fee'),
        ],
      ),
    );
  }

  Widget _buildStatTile(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: context.bgSecondary, borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.textPrimary)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: context.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSection() {
    return Container(
      decoration: BoxDecoration(
        color: context.bgSecondary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Container(
              height: 44,
              decoration: BoxDecoration(color: context.bgTertiary, borderRadius: BorderRadius.circular(22)),
              child: TabBar(
                controller: _tabController,
                onTap: (_) => setState(() {}),
                indicator: BoxDecoration(
                  color: context.isDark ? context.accent : const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(22),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: context.isDark ? Colors.black : Colors.white,
                unselectedLabelColor: context.textSecondary,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                dividerColor: Colors.transparent,
                tabs: const [Tab(text: 'Transactions'), Tab(text: 'Earnings')],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _tabController.index == 0 ? _buildTransactionsList() : _buildEarningsList(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildTransactionsList() {
    final txnAsync = ref.watch(walletTransactionsProvider);
    return txnAsync.when(
      data: (txns) {
        if (txns.isEmpty) return _buildEmpty('No transactions yet');
        return Column(
          children: txns.take(30).map((t) {
            final amount = (t['amount'] as num?)?.toDouble() ?? 0.0;
            final isCredit = amount > 0;
            final desc = t['description'] as String? ?? '';
            final date = DateTime.tryParse(t['created_at'] ?? '') ?? DateTime.now();
            final status = t['status'] as String? ?? 'completed';

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: isCredit ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                      size: 18,
                      color: isCredit ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(desc, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(DateFormat('d MMM, h:mm a').format(date), style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                            if (status != 'completed') ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: status == 'pending_approval' ? const Color(0xFFFFF3E0) : const Color(0xFFFFEBEE),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(status.replaceAll('_', ' '), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                                  color: status == 'pending_approval' ? const Color(0xFFE65100) : const Color(0xFFC62828))),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${isCredit ? '+' : ''}\u20a6${_formatter.format(amount.abs().toInt())}',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isCredit ? const Color(0xFF2E7D32) : const Color(0xFFE65100)),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A1A1A)))),
      error: (_, __) => _buildEmpty('Failed to load transactions'),
    );
  }

  Widget _buildEarningsList() {
    final earningsAsync = ref.watch(earningsProvider);
    return earningsAsync.when(
      data: (data) {
        final recent = (data['recent_earnings'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        if (recent.isEmpty) return _buildEmpty('No earnings yet');
        return Column(
          children: recent.map((e) {
            final carName = e['car_name'] as String? ?? 'Unknown';
            final earned = (e['earned'] as num?)?.toDouble() ?? 0.0;
            final renter = e['renter_name'] as String? ?? '';
            final date = DateTime.tryParse(e['completed_at'] ?? '') ?? DateTime.now();

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF2E7D32)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(carName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text('$renter \u2022 ${DateFormat('d MMM').format(date)}', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                      ],
                    ),
                  ),
                  Text('+\u20a6${_formatter.format(earned.toInt())}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32))),
                ],
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A1A1A)))),
      error: (_, __) => _buildEmpty('Failed to load earnings'),
    );
  }

  Widget _buildEmpty(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(child: Text(message, style: TextStyle(fontSize: 13, color: context.textSecondary))),
    );
  }

  // ─── Withdraw Bottom Sheet ────────────────────────────────

  void _showWithdrawSheet(double balance) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WithdrawSheet(balance: balance, onComplete: _refresh),
    );
  }
}

// ─── Withdraw Sheet Widget ──────────────────────────────────

class _WithdrawSheet extends ConsumerStatefulWidget {
  final double balance;
  final VoidCallback onComplete;

  const _WithdrawSheet({required this.balance, required this.onComplete});

  @override
  ConsumerState<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends ConsumerState<_WithdrawSheet> {
  final _amountController = TextEditingController();
  final _accountController = TextEditingController();
  String? _selectedBankCode;
  String? _selectedBankName;
  String? _selectedBankLogo;
  String? _resolvedAccountName;
  bool _isVerifying = false;
  bool _isWithdrawing = false;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    _accountController.dispose();
    super.dispose();
  }

  Future<void> _verifyAccount() async {
    if (_selectedBankCode == null || _accountController.text.length != 10) return;
    setState(() { _isVerifying = true; _resolvedAccountName = null; });

    final client = ref.read(apiClientProvider);
    final resp = await client.post('/payments/verify-account', body: {
      'account_number': _accountController.text,
      'bank_code': _selectedBankCode,
    });

    setState(() {
      _isVerifying = false;
      if (resp.isSuccess) {
        _resolvedAccountName = resp.body['account_name'] as String?;
      } else {
        _resolvedAccountName = null;
        _error = resp.body['error'] as String? ?? 'Could not verify account';
      }
    });
  }

  Future<void> _withdraw() async {
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount < 1000) {
      setState(() => _error = 'Minimum withdrawal is \u20a61,000');
      return;
    }
    if (amount > widget.balance) {
      setState(() => _error = 'Insufficient balance');
      return;
    }
    if (_selectedBankCode == null || _accountController.text.length != 10) {
      setState(() => _error = 'Please enter valid bank details');
      return;
    }

    setState(() { _isWithdrawing = true; _error = null; });

    final client = ref.read(apiClientProvider);
    final resp = await client.post('/payments/withdraw', body: {
      'amount': amount,
      'bank_code': _selectedBankCode,
      'account_number': _accountController.text,
    });

    setState(() => _isWithdrawing = false);

    if (resp.isSuccess) {
      widget.onComplete();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(resp.body['message'] ?? 'Withdrawal initiated'), backgroundColor: const Color(0xFF2E7D32)),
        );
      }
    } else {
      setState(() => _error = resp.body['error'] as String? ?? 'Withdrawal failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final banksAsync = ref.watch(banksProvider);
    final formatter = NumberFormat('#,##0', 'en_US');

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              const Text('Withdraw Funds', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
              const SizedBox(height: 4),
              Text('Available: \u20a6${formatter.format(widget.balance.toInt())}', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
              const SizedBox(height: 24),

              // Amount
              const Text('Amount', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
              const SizedBox(height: 8),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _inputDecoration('Enter amount'),
              ),
              const SizedBox(height: 20),

              // Bank
              const Text('Bank', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
              const SizedBox(height: 8),
              banksAsync.when(
                data: (banks) => GestureDetector(
                  onTap: () => _showBankPicker(banks),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      children: [
                        if (_selectedBankName != null) ...[
                          _selectedBankLogo != null && _selectedBankLogo!.isNotEmpty && !_selectedBankLogo!.contains('default-image')
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(_selectedBankLogo!, width: 36, height: 36, fit: BoxFit.contain, errorBuilder: (_, __, ___) => _bankIcon(_selectedBankName!)),
                                )
                              : _bankIcon(_selectedBankName!),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Text(
                            _selectedBankName ?? 'Select bank',
                            style: TextStyle(fontSize: 14, color: _selectedBankName != null ? const Color(0xFF1A1A1A) : Colors.grey, fontWeight: _selectedBankName != null ? FontWeight.w500 : FontWeight.normal),
                          ),
                        ),
                        Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey[400], size: 22),
                      ],
                    ),
                  ),
                ),
                loading: () => Container(
                  height: 50,
                  decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(14)),
                  child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                ),
                error: (_, __) => const Text('Failed to load banks', style: TextStyle(color: Colors.red, fontSize: 13)),
              ),
              const SizedBox(height: 20),

              // Account number
              const Text('Account Number', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
              const SizedBox(height: 8),
              TextField(
                controller: _accountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                decoration: _inputDecoration('10-digit account number'),
                onChanged: (val) {
                  if (val.length == 10 && _selectedBankCode != null) _verifyAccount();
                },
              ),

              // Resolved name
              if (_isVerifying)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Row(children: [SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 8), Text('Verifying...', style: TextStyle(fontSize: 12, color: Colors.grey))]),
                ),
              if (_resolvedAccountName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(children: [
                    const Icon(Icons.check_circle, size: 16, color: Color(0xFF2E7D32)),
                    const SizedBox(width: 6),
                    Text(_resolvedAccountName!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32))),
                  ]),
                ),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.red)),
                ),

              const SizedBox(height: 28),

              // Withdraw button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isWithdrawing ? null : _withdraw,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A1A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isWithdrawing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Withdraw', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBankPicker(List<Map<String, dynamic>> banks) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BankPickerSheet(
        banks: banks,
        selectedCode: _selectedBankCode,
        onSelected: (code, name) {
          final bank = banks.firstWhere((b) => b['code'] == code, orElse: () => {});
          setState(() {
            _selectedBankCode = code;
            _selectedBankName = name;
            _selectedBankLogo = bank['logo'] as String?;
            _resolvedAccountName = null;
          });
          if (_accountController.text.length == 10) _verifyAccount();
        },
      ),
    );
  }

  Widget _bankIcon(String bankName) {
    final name = bankName.toLowerCase();
    Color bg;
    String letter;

    if (name.contains('gtb') || name.contains('guaranty')) {
      bg = const Color(0xFFE65100); letter = 'GT';
    } else if (name.contains('first bank') || name.contains('firstbank')) {
      bg = const Color(0xFF1565C0); letter = 'FB';
    } else if (name.contains('access')) {
      bg = const Color(0xFFE65100); letter = 'AC';
    } else if (name.contains('zenith')) {
      bg = const Color(0xFFC62828); letter = 'ZB';
    } else if (name.contains('uba') || name.contains('united bank')) {
      bg = const Color(0xFFC62828); letter = 'UB';
    } else if (name.contains('kuda')) {
      bg = const Color(0xFF7B1FA2); letter = 'KD';
    } else if (name.contains('opay')) {
      bg = const Color(0xFF2E7D32); letter = 'OP';
    } else if (name.contains('palmpay')) {
      bg = const Color(0xFF1565C0); letter = 'PP';
    } else if (name.contains('moniepoint') || name.contains('teamapt')) {
      bg = const Color(0xFF1565C0); letter = 'MP';
    } else if (name.contains('stanbic')) {
      bg = const Color(0xFF1565C0); letter = 'SB';
    } else if (name.contains('sterling')) {
      bg = const Color(0xFFC62828); letter = 'ST';
    } else if (name.contains('wema') || name.contains('alat')) {
      bg = const Color(0xFF7B1FA2); letter = 'WM';
    } else if (name.contains('fidelity')) {
      bg = const Color(0xFF2E7D32); letter = 'FD';
    } else if (name.contains('union')) {
      bg = const Color(0xFF1565C0); letter = 'UN';
    } else if (name.contains('ecobank')) {
      bg = const Color(0xFF1565C0); letter = 'EC';
    } else if (name.contains('fcmb')) {
      bg = const Color(0xFF7B1FA2); letter = 'FC';
    } else {
      bg = const Color(0xFF616161);
      letter = bankName.length >= 2 ? bankName.substring(0, 2).toUpperCase() : bankName.toUpperCase();
    }

    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Center(child: Text(letter, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800))),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
      filled: true,
      fillColor: const Color(0xFFF5F5F5),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}

// ─── Bank Picker Bottom Sheet ────────────────────────────

class _BankPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> banks;
  final String? selectedCode;
  final void Function(String code, String name) onSelected;

  const _BankPickerSheet({required this.banks, this.selectedCode, required this.onSelected});

  @override
  State<_BankPickerSheet> createState() => _BankPickerSheetState();
}

class _BankPickerSheetState extends State<_BankPickerSheet> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.banks;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    final q = query.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.banks
          : widget.banks.where((b) => (b['name'] as String? ?? '').toLowerCase().contains(q)).toList();
    });
  }

  Widget _bankIcon(Map<String, dynamic> bank) {
    final logo = bank['logo'] as String?;
    final name = bank['name'] as String? ?? '??';

    if (logo != null && logo.isNotEmpty && !logo.contains('default-image')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          logo,
          width: 40, height: 40,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _fallbackIcon(name),
        ),
      );
    }
    return _fallbackIcon(name);
  }

  Widget _fallbackIcon(String bankName) {
    final letter = bankName.length >= 2 ? bankName.substring(0, 2).toUpperCase() : bankName.toUpperCase();
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(color: const Color(0xFFF2F2F2), borderRadius: BorderRadius.circular(12)),
      child: Center(child: Text(letter, style: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 13, fontWeight: FontWeight.w800))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        children: [
          // Handle
          Center(child: Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
          // Header + Search
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Bank', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
                const SizedBox(height: 14),
                TextField(
                  controller: _searchController,
                  onChanged: _onSearch,
                  autofocus: true,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search banks...',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400], size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Bank list
          Expanded(
            child: _filtered.isEmpty
                ? Center(child: Text('No banks found', style: TextStyle(color: Colors.grey[400], fontSize: 14)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final bank = _filtered[i];
                      final code = bank['code'] as String? ?? '';
                      final name = bank['name'] as String? ?? '';
                      final isSelected = code == widget.selectedCode;

                      return GestureDetector(
                        onTap: () {
                          widget.onSelected(code, name);
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[100]!))),
                          child: Row(
                            children: [
                              _bankIcon(bank),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: const Color(0xFF1A1A1A),
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 20),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
