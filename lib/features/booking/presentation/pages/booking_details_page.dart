import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qent/core/services/api_client.dart';
import 'package:qent/features/booking/domain/models/booking_confirmation.dart';
import 'package:qent/features/booking/domain/models/booking_form.dart';
import 'package:qent/features/booking/presentation/pages/payment_methods_page.dart';
import 'package:qent/features/home/domain/models/car.dart';
import 'package:qent/features/search/presentation/widgets/custom_date_range_picker.dart';
import 'package:qent/features/search/presentation/widgets/location_picker.dart';

class BookingDetailsPage extends StatefulWidget {
  final Car car;

  const BookingDetailsPage({
    super.key,
    required this.car,
  });

  @override
  State<BookingDetailsPage> createState() => _BookingDetailsPageState();
}

class _BookingDetailsPageState extends State<BookingDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _contactController = TextEditingController();
  final _locationController = TextEditingController();

  bool _bookWithDriver = false;
  bool _isLoading = false;
  Gender? _selectedGender;
  RentalDuration? _selectedRentalDuration;
  DateTime? _pickupDate;
  DateTime? _returnDate;
  TimeOfDay? _pickupTime;
  TimeOfDay? _returnTime;
  double _totalPrice = 0.0;

  // Validation error messages for non-FormField widgets
  String? _genderError;
  String? _dateError;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _selectedRentalDuration = RentalDuration.day;
    _calculateTotal();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _calculateTotal() {
    if (_pickupDate != null && _returnDate != null) {
      final days = _returnDate!.difference(_pickupDate!).inDays;
      double basePrice = widget.car.pricePerDay;

      switch (_selectedRentalDuration) {
        case RentalDuration.hour:
          basePrice = basePrice / 24;
          _totalPrice = basePrice * _returnDate!.difference(_pickupDate!).inHours;
          break;
        case RentalDuration.day:
          _totalPrice = basePrice * (days > 0 ? days : 1);
          break;
        case RentalDuration.weekly:
          _totalPrice = (basePrice * 7) * (days / 7).ceil();
          break;
        case RentalDuration.monthly:
          _totalPrice = (basePrice * 30) * (days / 30).ceil();
          break;
        default:
          _totalPrice = basePrice * (days > 0 ? days : 1);
      }

      if (_bookWithDriver) {
        _totalPrice += 100;
      }
    } else {
      _totalPrice = widget.car.pricePerDay;
    }

    setState(() {});
  }

  bool _validateForm() {
    bool isValid = _formKey.currentState!.validate();

    // Validate gender
    if (_selectedGender == null) {
      setState(() => _genderError = 'Please select your gender');
      isValid = false;
    } else {
      setState(() => _genderError = null);
    }

    // Validate dates
    if (_pickupDate == null || _returnDate == null) {
      setState(() => _dateError = 'Please select pickup and return dates');
      isValid = false;
    } else if (_returnDate!.isBefore(_pickupDate!) || _returnDate!.isAtSameMomentAs(_pickupDate!)) {
      setState(() => _dateError = 'Return date must be after pickup date');
      isValid = false;
    } else if (_pickupDate!.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
      setState(() => _dateError = 'Pickup date cannot be in the past');
      isValid = false;
    } else {
      setState(() => _dateError = null);
    }

    // Validate location
    if (_locationController.text.trim().isEmpty) {
      setState(() => _locationError = 'Please select a pickup location');
      isValid = false;
    } else {
      setState(() => _locationError = null);
    }

    return isValid;
  }

  Future<void> _submitBooking() async {
    if (!_validateForm()) return;

    setState(() => _isLoading = true);

    try {
      final startDate = DateFormat('yyyy-MM-dd').format(_pickupDate!);
      final endDate = DateFormat('yyyy-MM-dd').format(_returnDate!);

      final response = await ApiClient().post('/bookings', body: {
        'car_id': widget.car.id,
        'start_date': startDate,
        'end_date': endDate,
      });

      if (!mounted) return;

      if (response.isSuccess) {
        final booking = BookingResponse.fromJson(response.body as Map<String, dynamic>);

        final confirmation = BookingConfirmation(
          bookingId: booking.id,
          customerName: _fullNameController.text.trim(),
          email: _emailController.text.trim(),
          pickupDate: _pickupDate!,
          pickupTime: _pickupTime ?? const TimeOfDay(hour: 10, minute: 0),
          returnDate: _returnDate!,
          returnTime: _returnTime ?? const TimeOfDay(hour: 17, minute: 0),
          location: _locationController.text.trim(),
          amount: booking.subtotal,
          serviceFee: booking.serviceFee,
          protectionFee: booking.protectionFee,
          totalAmount: booking.totalAmount,
          paymentMethod: 'Card',
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentMethodsPage(
              car: widget.car,
              confirmationData: confirmation,
            ),
          ),
        );
      } else {
        _showError(response.errorMessage);
      }
    } catch (e) {
      if (mounted) _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _selectDates() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CustomDateRangePicker(
        initialStartDate: _pickupDate,
        initialEndDate: _returnDate,
        initialPickupTime: _pickupTime,
        initialDropTime: _returnTime,
      ),
    );

    if (result != null) {
      setState(() {
        _pickupDate = result['startDate'] as DateTime?;
        _returnDate = result['endDate'] as DateTime?;
        _pickupTime = result['pickupTime'] as TimeOfDay?;
        _returnTime = result['dropTime'] as TimeOfDay?;
        _dateError = null;
      });
      _calculateTotal();
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${date.day}/ ${months[date.month - 1]} /${date.year}';
  }

  void _openLocationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LocationPicker(
        initialLocation: _locationController.text.isNotEmpty
            ? _locationController.text
            : null,
        onLocationSelected: (location) {
          setState(() {
            _locationController.text = location.displayName;
            _locationError = null;
          });
          Navigator.of(context).pop();
        },
      ),
    );
  }

  String _formatPrice(double price) {
    if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(price % 1000 == 0 ? 0 : 1)}k';
    }
    return price.toInt().toString();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context),
            _buildStepper(activeStep: 0),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      _buildBookWithDriverSection(),
                      const SizedBox(height: 24),
                      _buildUserInfoSection(),
                      const SizedBox(height: 24),
                      _buildGenderSection(),
                      const SizedBox(height: 24),
                      _buildRentalDateSection(),
                      const SizedBox(height: 24),
                      _buildLocationSection(),
                      SizedBox(height: screenHeight * 0.15),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildContinueButton(context, screenWidth),
    ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.arrow_back_rounded, size: 20, color: Color(0xFF1A1A1A)),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Booking Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
          ),
          const SizedBox(width: 42),
        ],
      ),
    );
  }

  Widget _buildStepper({required int activeStep}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Column(
        children: [
          Row(
            children: [
              _buildStepCircle(0, activeStep),
              Expanded(child: Container(height: 2, color: activeStep > 0 ? const Color(0xFF1A1A1A) : Colors.grey[300])),
              _buildStepCircle(1, activeStep),
              Expanded(child: Container(height: 2, color: activeStep > 1 ? const Color(0xFF1A1A1A) : Colors.grey[300])),
              _buildStepCircle(2, activeStep),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Details', style: TextStyle(fontSize: 11, fontWeight: activeStep == 0 ? FontWeight.w600 : FontWeight.w400, color: activeStep == 0 ? const Color(0xFF1A1A1A) : Colors.grey[500])),
              Text('Payment', style: TextStyle(fontSize: 11, fontWeight: activeStep == 1 ? FontWeight.w600 : FontWeight.w400, color: activeStep == 1 ? const Color(0xFF1A1A1A) : Colors.grey[500])),
              Text('Confirm', style: TextStyle(fontSize: 11, fontWeight: activeStep == 2 ? FontWeight.w600 : FontWeight.w400, color: activeStep == 2 ? const Color(0xFF1A1A1A) : Colors.grey[500])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepCircle(int step, int activeStep) {
    final isCompleted = step < activeStep;
    final isActive = step == activeStep;

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: (isActive || isCompleted) ? const Color(0xFF1A1A1A) : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: (isActive || isCompleted) ? const Color(0xFF1A1A1A) : Colors.grey[300]!,
          width: 2,
        ),
      ),
      child: Center(
        child: isCompleted
            ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
            : Text(
                '${step + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : Colors.grey[500],
                ),
              ),
      ),
    );
  }

  Widget _buildBookWithDriverSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person_rounded, size: 22, color: Color(0xFF1A1A1A)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Book with driver',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Don\'t have a driver? Book with driver.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _bookWithDriver,
            onChanged: (value) {
              setState(() {
                _bookWithDriver = value;
                _calculateTotal();
              });
            },
            activeColor: const Color(0xFF1A1A1A),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildValidatedField(
          controller: _fullNameController,
          icon: Icons.person_outline_rounded,
          hintText: 'Full Name*',
          keyboardType: TextInputType.name,
          validator: (value) {
            if (value == null || value.trim().isEmpty) return 'Full name is required';
            if (value.trim().length < 2) return 'Name must be at least 2 characters';
            return null;
          },
        ),
        const SizedBox(height: 14),
        _buildValidatedField(
          controller: _emailController,
          icon: Icons.email_outlined,
          hintText: 'Email Address*',
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.trim().isEmpty) return 'Email is required';
            final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$');
            if (!emailRegex.hasMatch(value.trim())) return 'Enter a valid email address';
            return null;
          },
        ),
        const SizedBox(height: 14),
        _buildValidatedField(
          controller: _contactController,
          icon: Icons.phone_outlined,
          hintText: 'Phone Number*',
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.trim().isEmpty) return 'Phone number is required';
            final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
            if (digitsOnly.length < 7 || digitsOnly.length > 15) return 'Enter a valid phone number';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildValidatedField({
    required TextEditingController controller,
    required IconData icon,
    required String hintText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: TextInputAction.next,
      style: const TextStyle(fontSize: 14),
      validator: validator,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.grey[500], size: 20),
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        filled: true,
        fillColor: const Color(0xFFF8F8F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF1A1A1A), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        errorStyle: const TextStyle(fontSize: 11),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
    );
  }

  Widget _buildGenderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gender',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildGenderButton('Male', Icons.male, Gender.male)),
            const SizedBox(width: 10),
            Expanded(child: _buildGenderButton('Female', Icons.female, Gender.female)),
            const SizedBox(width: 10),
            Expanded(child: _buildGenderButton('Others', Icons.transgender, Gender.others)),
          ],
        ),
        if (_genderError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 12),
            child: Text(
              _genderError!,
              style: const TextStyle(fontSize: 11, color: Colors.red),
            ),
          ),
      ],
    );
  }

  Widget _buildGenderButton(String label, IconData icon, Gender gender) {
    final isSelected = _selectedGender == gender;
    final hasError = _genderError != null;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGender = gender;
          _genderError = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1A1A1A) : const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(14),
          border: hasError && !isSelected
              ? Border.all(color: Colors.red.withValues(alpha: 0.5), width: 1)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[600],
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRentalDateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rental Date & Time',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildDurationButton('Hour', RentalDuration.hour)),
            const SizedBox(width: 10),
            Expanded(child: _buildDurationButton('Day', RentalDuration.day)),
            const SizedBox(width: 10),
            Expanded(child: _buildDurationButton('Weekly', RentalDuration.weekly)),
            const SizedBox(width: 10),
            Expanded(child: _buildDurationButton('Monthly', RentalDuration.monthly)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildDateField(
                'Pick up Date',
                _pickupDate != null ? _formatDate(_pickupDate!) : null,
                onTap: _selectDates,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDateField(
                'Return Date',
                _returnDate != null ? _formatDate(_returnDate!) : null,
                onTap: _selectDates,
              ),
            ),
          ],
        ),
        if (_dateError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 12),
            child: Text(
              _dateError!,
              style: const TextStyle(fontSize: 11, color: Colors.red),
            ),
          ),
      ],
    );
  }

  Widget _buildDurationButton(String label, RentalDuration duration) {
    final isSelected = _selectedRentalDuration == duration;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRentalDuration = duration;
          _calculateTotal();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1A1A1A) : const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  Widget _buildDateField(String label, String? dateText, {required VoidCallback onTap}) {
    final hasError = _dateError != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(14),
          border: hasError && dateText == null
              ? Border.all(color: Colors.red.withValues(alpha: 0.5), width: 1)
              : null,
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, color: Colors.grey[500], size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                dateText ?? label,
                style: TextStyle(
                  fontSize: 13,
                  color: dateText != null ? const Color(0xFF1A1A1A) : Colors.grey[400],
                  fontWeight: dateText != null ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection() {
    final hasError = _locationError != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Car Location',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _openLocationPicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(14),
              border: hasError
                  ? Border.all(color: Colors.red.withValues(alpha: 0.5), width: 1)
                  : null,
            ),
            child: Row(
              children: [
                Icon(Icons.location_on_outlined, color: Colors.grey[500], size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _locationController.text.isEmpty
                        ? 'Select location'
                        : _locationController.text,
                    style: TextStyle(
                      fontSize: 13,
                      color: _locationController.text.isEmpty
                          ? Colors.grey[400]
                          : const Color(0xFF1A1A1A),
                      fontWeight: _locationController.text.isNotEmpty
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey[400], size: 14),
              ],
            ),
          ),
        ),
        if (_locationError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 12),
            child: Text(
              _locationError!,
              style: const TextStyle(fontSize: 11, color: Colors.red),
            ),
          ),
      ],
    );
  }

  Widget _buildContinueButton(BuildContext context, double screenWidth) {
    return Container(
      padding: EdgeInsets.only(
        left: screenWidth * 0.05,
        right: screenWidth * 0.05,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitBooking,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A1A1A),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[400],
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '\u00b7',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '\u20a6${_formatPrice(_totalPrice)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
      ),
    );
  }
}
