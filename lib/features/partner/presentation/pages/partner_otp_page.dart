import 'package:flutter/material.dart';
import 'package:qent/features/partner/presentation/pages/partner_payout_setup_page.dart';

class PartnerOtpPage extends StatefulWidget {
  const PartnerOtpPage({super.key});

  @override
  State<PartnerOtpPage> createState() => _PartnerOtpPageState();
}

class _PartnerOtpPageState extends State<PartnerOtpPage> {
  final _controllers = List.generate(4, (_) => TextEditingController());

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('OTP Verification', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 16)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 8),
              Text(
                'Enter your Verification Code',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey[900]),
              ),
              const SizedBox(height: 8),
              Text(
                'Please enter the OTP to verify your partner account.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) => _otpBox(_controllers[i])),
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
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PartnerPayoutSetupPage()));
                  },
                  child: const Text('Verify Now'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _otpBox(TextEditingController c) {
    return Container(
      width: 48,
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: TextField(
        controller: c,
        textAlign: TextAlign.center,
        maxLength: 1,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
        onChanged: (v) {
          if (v.length == 1) FocusScope.of(context).nextFocus();
        },
      ),
    );
  }
}


