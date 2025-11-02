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
    _selectedRentalDuration = RentalDuration.day; // Default to Day
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
        _totalPrice += 100; // Additional fee for driver
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, size: 20, color: Colors.black),
          ),
        ),
        title: const Text(
          'Booking Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        actions: [
          GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.more_vert, size: 20, color: Colors.black),
            ),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildProgressIndicator(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
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
      bottomNavigationBar: _buildPayNowButton(context, screenWidth),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Step 1 - Active
              _buildStepNode(isActive: true),
              // Solid line connector
              Expanded(
                child: Container(
                  height: 2,
                  color: Colors.black87,
                ),
              ),
              // Step 2 - Inactive
              _buildStepNode(isActive: false),
              // Solid line connector
              Expanded(
                child: Container(
                  height: 2,
                  color: Colors.black87,
                ),
              ),
              // Step 3 - Inactive
              _buildStepNode(isActive: false),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: Text(
                  'Booking details',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: Colors.black87,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Payment methods',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 11,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'confirmation',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepNode({required bool isActive}) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: Colors.black87,
        shape: BoxShape.circle,
        border: isActive
            ? Border.all(color: Colors.white, width: 2)
            : null,
      ),
      child: isActive
          ? Container(
              margin: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }

  Widget _buildBookWithDriverSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Book with driver',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Don\'t have a driver? book with driver.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
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
            activeColor: const Color(0xFF2C2C2C),
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
          icon: Icons.person,
          hintText: 'Full Name*',
          keyboardType: TextInputType.name,
        ),
        const SizedBox(height: 16),
        _buildInputField(
          controller: _emailController,
          icon: Icons.email,
          hintText: 'Email Address*',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        _buildInputField(
          controller: _contactController,
          icon: Icons.phone,
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
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textInputAction: TextInputAction.next,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey[600], size: 20),
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
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildGenderButton(
                'Male',
                Icons.male,
                Gender.male,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildGenderButton(
                'Female',
                Icons.female,
                Gender.female,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildGenderButton(
                'Others',
                Icons.transgender,
                Gender.others,
              ),
            ),
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
          color: isSelected ? const Color(0xFF2C2C2C) : Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? const Color(0xFF2C2C2C) : Colors.grey[300]!,
          ),
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
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildDurationButton('Hour', RentalDuration.hour),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDurationButton('Day', RentalDuration.day),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDurationButton('Weekly', RentalDuration.weekly),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDurationButton('Monthly', RentalDuration.monthly),
            ),
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
          color: isSelected ? const Color(0xFF2C2C2C) : Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? const Color(0xFF2C2C2C) : Colors.grey[300]!,
          ),
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
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: Colors.grey[600], size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                dateText ?? label,
                style: TextStyle(
                  fontSize: 13,
                  color: dateText != null ? Colors.black87 : Colors.grey[400],
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
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _openLocationPicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on, color: Colors.grey[600], size: 18),
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
                          : Colors.black87,
                      fontWeight: _locationController.text.isNotEmpty 
                          ? FontWeight.w500 
                          : FontWeight.normal,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: Colors.grey[600], size: 14),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPayNowButton(BuildContext context, double screenWidth) {
    return Container(
      padding: EdgeInsets.only(
        left: screenWidth * 0.04,
        right: screenWidth * 0.04,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child:         ElevatedButton(
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            // Create mock confirmation data (will be replaced with actual booking logic)
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
          backgroundColor: const Color(0xFF2C2C2C),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          elevation: 0,
        ),
        child: Row(
          //mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '\$${_totalPrice.toInt()}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Pay Now',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

