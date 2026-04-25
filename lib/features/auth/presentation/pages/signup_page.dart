import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/core/services/email_verification_service.dart';
import 'package:qent/features/auth/presentation/pages/verification_code_page.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart';
import 'package:qent/core/theme/app_theme.dart';

String? validateEmail(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Please enter your email';
  }
  final email = value.trim().toLowerCase();

  // Basic format check
  final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  if (!emailRegex.hasMatch(email)) {
    return 'Please enter a valid email address';
  }

  final domain = email.split('@').last;

  // Common domain typo corrections
  const domainTypos = {
    // Gmail
    'gimal.com': 'gmail.com',
    'gmial.com': 'gmail.com',
    'gmla.com': 'gmail.com',
    'gmali.com': 'gmail.com',
    'gmai.com': 'gmail.com',
    'gamil.com': 'gmail.com',
    'gnail.com': 'gmail.com',
    'gmaill.com': 'gmail.com',
    'gmaik.com': 'gmail.com',
    'gmil.com': 'gmail.com',
    'gmaol.com': 'gmail.com',
    'gmail.con': 'gmail.com',
    'gmail.cm': 'gmail.com',
    'gmail.co': 'gmail.com',
    'gmail.vom': 'gmail.com',
    'gmail.cim': 'gmail.com',
    'gmail.om': 'gmail.com',
    // Yahoo
    'yaho.com': 'yahoo.com',
    'yahooo.com': 'yahoo.com',
    'yhoo.com': 'yahoo.com',
    'yahoo.con': 'yahoo.com',
    'yaoo.com': 'yahoo.com',
    // Hotmail
    'hotmal.com': 'hotmail.com',
    'hotmial.com': 'hotmail.com',
    'hotamil.com': 'hotmail.com',
    'hotmail.con': 'hotmail.com',
    // Outlook
    'outllok.com': 'outlook.com',
    'outlok.com': 'outlook.com',
    'outlook.con': 'outlook.com',
    'outook.com': 'outlook.com',
  };

  if (domainTypos.containsKey(domain)) {
    return 'Did you mean ${email.split('@').first}@${domainTypos[domain]}?';
  }

  return null;
}

class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _countryController = TextEditingController();
  bool _obscurePassword = true;
  String _selectedCountry = 'Nigeria'; // Default to Nigeria
  bool _isSendingCode = false;
  final EmailVerificationService _verificationService = EmailVerificationService();

  // Country data with flag emojis — Nigeria prioritized
  static final List<_CountryData> _countries = [
    _CountryData('🇳🇬', 'Nigeria'),
    _CountryData('🇬🇭', 'Ghana'),
    _CountryData('🇰🇪', 'Kenya'),
    _CountryData('🇿🇦', 'South Africa'),
    _CountryData('🇺🇸', 'United States'),
    _CountryData('🇬🇧', 'United Kingdom'),
    _CountryData('🇨🇦', 'Canada'),
    _CountryData('🇦🇺', 'Australia'),
    _CountryData('🇩🇪', 'Germany'),
    _CountryData('🇫🇷', 'France'),
    _CountryData('🇪🇸', 'Spain'),
    _CountryData('🇮🇹', 'Italy'),
    _CountryData('🇯🇵', 'Japan'),
    _CountryData('🇨🇳', 'China'),
    _CountryData('🇮🇳', 'India'),
    _CountryData('🇧🇷', 'Brazil'),
    _CountryData('🇲🇽', 'Mexico'),
    _CountryData('🇦🇪', 'UAE'),
    _CountryData('🇸🇦', 'Saudi Arabia'),
    _CountryData('🇪🇬', 'Egypt'),
    _CountryData('🇹🇿', 'Tanzania'),
    _CountryData('🇷🇼', 'Rwanda'),
    _CountryData('🌍', 'Other'),
  ];

  String get _selectedFlag {
    return _countries.firstWhere(
      (c) => c.name == _selectedCountry,
      orElse: () => _CountryData('🌍', 'Other'),
    ).flag;
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CountryPickerSheet(
        countries: _countries,
        selected: _selectedCountry,
        onSelected: (country) {
          setState(() => _selectedCountry = country);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();

    setState(() {
      _isSendingCode = true;
    });

    try {
      // Request backend to generate and send verification code
      final emailSent = await _verificationService.sendVerificationCode(email);

      if (!mounted) return;

      if (emailSent) {
        // Create masked email for display
        final maskedEmail = _maskEmail(email);

        // Navigate to verification page
        final verified = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => VerificationCodePage(
              email: email,
              maskedEmail: maskedEmail,
            ),
          ),
        );

        // If verification successful, complete signup
        if (verified == true && mounted) {
          await ref.read(authControllerProvider.notifier).signUp(
                email: email,
                password: _passwordController.text,
                fullName: _fullNameController.text.trim(),
                country: _selectedCountry,
              );
        } else if (mounted) {
          // User cancelled or verification failed
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verification cancelled or failed'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to send verification code. Please try again.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending code: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingCode = false;
        });
      }
    }
  }

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;

    final username = parts[0];
    final domain = parts[1];

    // Mask username (show first char, mask middle, show last char if long enough)
    String maskedUsername;
    if (username.length <= 2) {
      maskedUsername = '*' * username.length;
    } else {
      maskedUsername = '${username[0]}${'*' * (username.length - 2)}${username[username.length - 1]}';
    }

    // Mask domain (show first 3 chars, mask rest)
    final domainParts = domain.split('.');
    if (domainParts.isEmpty) return email;

    final domainName = domainParts[0];
    final domainExtension = domainParts.length > 1 ? '.${domainParts.sublist(1).join('.')}' : '';

    String maskedDomain;
    if (domainName.length <= 3) {
      maskedDomain = '*' * domainName.length;
    } else {
      maskedDomain = '${domainName.substring(0, 3)}${'*' * (domainName.length - 3)}';
    }

    return '$maskedUsername@$maskedDomain$domainExtension';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading || _isSendingCode;

    // Navigate on successful signup (check this FIRST)
    if (authState.user != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pushReplacementNamed(context, '/home');
      });
    }
    // Show error only if signup actually failed (no user)
    else if (authState.errorMessage != null && !authState.isLoading && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showError(_getErrorMessage(authState.errorMessage!));
        // Clear the error so it doesn't show again on rebuild
        ref.read(authControllerProvider.notifier).clearError();
      });
    }

    return Scaffold(
      backgroundColor: context.bgPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAppBar(),
                const SizedBox(height: 32),
                _buildTitle(),
                const SizedBox(height: 32),
                _buildForm(),
                const SizedBox(height: 32),
                _buildSignUpButton(isLoading),
                const SizedBox(height: 16),
                _buildLoginButton(),
                const SizedBox(height: 24),
                _buildSeparator(),
                const SizedBox(height: 24),
                _buildSocialButtons(),
                const SizedBox(height: 32),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            child: Image.asset(
              'assets/images/image_logo.png',
              width: 30,
              height: 30,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Qent',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Center(
      child: Text(
        'Sign Up',
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: context.textPrimary,
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          TextFormField(
            controller: _fullNameController,
            keyboardType: TextInputType.name,
            textCapitalization: TextCapitalization.words,
            style: TextStyle(color: context.textPrimary),
            decoration: InputDecoration(
              hintText: 'Full Name',
              hintStyle: TextStyle(color: context.textTertiary),
              filled: true,
              fillColor: context.inputBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.inputBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.inputBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.isDark ? context.accent : Colors.black),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your full name';
              }
              if (value.trim().length < 2) {
                return 'Name must be at least 2 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: context.textPrimary),
            decoration: InputDecoration(
              hintText: 'Email Address',
              hintStyle: TextStyle(color: context.textTertiary),
              filled: true,
              fillColor: context.inputBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.inputBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.inputBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.isDark ? context.accent : Colors.black),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            validator: validateEmail,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: TextStyle(color: context.textPrimary),
            decoration: InputDecoration(
              hintText: 'Password',
              hintStyle: TextStyle(color: context.textTertiary),
              filled: true,
              fillColor: context.inputBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.inputBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.inputBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.isDark ? context.accent : Colors.black),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: context.textTertiary,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a password';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _showCountryPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: context.inputBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.inputBorder),
              ),
              child: Row(
                children: [
                  Text(
                    _selectedFlag,
                    style: const TextStyle(fontSize: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedCountry,
                      style: TextStyle(fontSize: 16, color: context.textPrimary),
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down_rounded, color: context.textTertiary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpButton(bool isLoading) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: isLoading ? null : _handleSignUp,
          style: ElevatedButton.styleFrom(
            backgroundColor: context.isDark ? context.accent : const Color(0xFF2C2C2C),
            foregroundColor: context.isDark ? Colors.black : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  _isSendingCode ? 'Sending code...' : 'Sign up',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: OutlinedButton(
          onPressed: () {
            Navigator.pushNamed(context, '/login');
          },
          style: OutlinedButton.styleFrom(
            backgroundColor: context.bgSecondary,
            foregroundColor: context.textPrimary,
            side: BorderSide(color: context.borderColor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Login',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Expanded(child: Divider(color: context.borderColor)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Or',
              style: TextStyle(color: context.textSecondary, fontSize: 14),
            ),
          ),
          Expanded(child: Divider(color: context.borderColor)),
        ],
      ),
    );
  }

  Widget _buildSocialButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          _buildSocialButton(
            icon: Icons.apple,
            label: 'Apple pay',
            onPressed: () {
              // TODO: Implement Apple Sign In
            },
          ),
          const SizedBox(height: 12),
          _buildSocialButton(
            icon: Icons.g_mobiledata,
            label: 'Google Pay',
            onPressed: () {
              // TODO: Implement Google Sign In
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: context.bgSecondary,
          foregroundColor: context.textPrimary,
          side: BorderSide(color: context.borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 32),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Already have an account? ',
              style: TextStyle(color: context.textSecondary, fontSize: 14),
            ),
            GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, '/login');
              },
              child: Text(
                'Login.',
                style: TextStyle(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getErrorMessage(String error) {
    if (error.contains('email-already-in-use')) {
      return 'An account already exists with this email.';
    } else if (error.contains('invalid-email')) {
      return 'Invalid email address.';
    } else if (error.contains('operation-not-allowed')) {
      return 'Sign up is currently disabled.';
    } else if (error.contains('weak-password')) {
      return 'Password is too weak. Please choose a stronger password.';
    } else if (error.contains('network-request-failed')) {
      return 'Network error. Please check your connection.';
    }
    return 'Sign up failed. Please try again.';
  }

  void showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

// ---------- Country data model ----------

class _CountryData {
  final String flag;
  final String name;
  const _CountryData(this.flag, this.name);
}

// ---------- Searchable country picker bottom sheet ----------

class _CountryPickerSheet extends StatefulWidget {
  final List<_CountryData> countries;
  final String selected;
  final ValueChanged<String> onSelected;

  const _CountryPickerSheet({
    required this.countries,
    required this.selected,
    required this.onSelected,
  });

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  String _query = '';

  List<_CountryData> get _filtered {
    if (_query.isEmpty) return widget.countries;
    final q = _query.toLowerCase();
    return widget.countries.where((c) => c.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.65 + bottomPad,
      decoration: BoxDecoration(
        color: context.bgPrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Title
          Text(
            'Select Country',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              autofocus: false,
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search country...',
                hintStyle: TextStyle(color: context.textTertiary, fontSize: 15),
                prefixIcon: Icon(Icons.search, color: context.textTertiary, size: 20),
                filled: true,
                fillColor: context.inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Country list
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text(
                      'No countries found',
                      style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final c = _filtered[index];
                      final isSelected = c.name == widget.selected;
                      return ListTile(
                        onTap: () => widget.onSelected(c.name),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        selected: isSelected,
                        selectedTileColor: context.bgSecondary,
                        leading: Text(
                          c.flag,
                          style: const TextStyle(fontSize: 26),
                        ),
                        title: Text(
                          c.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: context.textPrimary,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle, color: context.textPrimary, size: 20)
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

