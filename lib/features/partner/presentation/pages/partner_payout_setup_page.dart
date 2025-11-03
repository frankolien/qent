import 'package:flutter/material.dart';

class PartnerPayoutSetupPage extends StatefulWidget {
  const PartnerPayoutSetupPage({super.key});

  @override
  State<PartnerPayoutSetupPage> createState() => _PartnerPayoutSetupPageState();
}

class _PartnerPayoutSetupPageState extends State<PartnerPayoutSetupPage> {
  String _method = 'bank';
  final _accountController = TextEditingController();

  @override
  void dispose() {
    _accountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Verify Statuses', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  CircleAvatar(backgroundColor: Colors.green, radius: 18, child: Icon(Icons.check, color: Colors.white)),
                  SizedBox(width: 12),
                  Text('Successful', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 8),
              Text('Your OTP verification was successful. Now, set how you receive partner payments.', style: TextStyle(color: Colors.grey[700])),
              const SizedBox(height: 24),
              const Text('Payment receive method', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Bank Account'),
                    selected: _method == 'bank',
                    onSelected: (_) => setState(() => _method = 'bank'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Mobile Money'),
                    selected: _method == 'momo',
                    onSelected: (_) => setState(() => _method = 'momo'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _accountController,
                decoration: InputDecoration(
                  labelText: _method == 'bank' ? 'Account Number / IBAN' : 'Wallet Number',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.settings.name == '/home' || route.isFirst);
                    // In a full implementation, persist payout method and mark user as partner
                  },
                  child: const Text('Next'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


