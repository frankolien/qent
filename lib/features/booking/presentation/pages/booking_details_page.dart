import 'package:flutter/material.dart';
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
  Gender? _selectedGender;
  RentalDuration? _selectedRentalDuration;
  DateTime? _pickupDate;
  DateTime? _returnDate;
  TimeOfDay? _pickupTime;
  TimeOfDay? _returnTime;
  double _totalPrice = 0.0;

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

    return Scaffold(
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
        _buildInputField(
          controller: _fullNameController,
          icon: Icons.person_outline_rounded,
          hintText: 'Full Name*',
          keyboardType: TextInputType.name,
        ),
        const SizedBox(height: 14),
        _buildInputField(
          controller: _emailController,
          icon: Icons.email_outlined,
          hintText: 'Email Address*',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        _buildInputField(
          controller: _contactController,
          icon: Icons.phone_outlined,
          hintText: 'Contact*',
          keyboardType: TextInputType.phone,
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required IconData icon,
    required String hintText,
    TextInputType? keyboardType,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textInputAction: TextInputAction.next,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey[500], size: 20),
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onChanged: (_) => _calculateTotal(),
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
      ],
    );
  }

  Widget _buildGenderButton(String label, IconData icon, Gender gender) {
    final isSelected = _selectedGender == gender;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGender = gender;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1A1A1A) : const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(14),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(14),
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
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            final confirmation = BookingConfirmation(
              bookingId: '00451',
              customerName: _fullNameController.text.isNotEmpty
                  ? _fullNameController.text
                  : 'Benjamin Jack',
              pickupDate: _pickupDate ?? DateTime.now(),
              pickupTime: _pickupTime ?? const TimeOfDay(hour: 10, minute: 30),
              returnDate: _returnDate ?? DateTime.now().add(const Duration(days: 3)),
              returnTime: _returnTime ?? const TimeOfDay(hour: 17, minute: 0),
              location: _locationController.text.isNotEmpty
                  ? _locationController.text
                  : 'Shore Dr, Chicago 0062 Usa',
              transactionId: '#141mtslv5854d58',
              amount: _totalPrice,
              serviceFee: 15.0,
              totalAmount: _totalPrice + 15.0,
              paymentMethod: 'Mastercard',
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
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A1A1A),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Row(
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
              '·',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Text(
              '₦${_formatPrice(_totalPrice)}',
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
