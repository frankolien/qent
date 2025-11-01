import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/features/search/domain/models/filter_options.dart';
import 'package:qent/features/search/domain/models/search_filters.dart';
import 'package:qent/features/search/presentation/providers/search_providers.dart';
import 'package:qent/features/search/presentation/widgets/custom_date_range_picker.dart';

class FilterBottomSheet extends ConsumerStatefulWidget {
  const FilterBottomSheet({super.key});

  @override
  ConsumerState<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends ConsumerState<FilterBottomSheet> {
  final TextEditingController _minPriceController = TextEditingController(text: '\$10');
  final TextEditingController _maxPriceController = TextEditingController(text: '\$230+');
  final TextEditingController _locationController = TextEditingController(text: 'Shore Dr, Chicago 0062 Usa');
  bool _showAllColors = false;

  @override
  void initState() {
    super.initState();
    // Initialize with default values, will be updated in build
    _minPriceController.text = '\$10';
    _maxPriceController.text = '\$230+';
    _locationController.text = 'Shore Dr, Chicago 0062 Usa';
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _updatePriceControllers() {
    final filters = ref.read(searchControllerProvider).filters;
    _minPriceController.text = '\$${filters.priceRange.start.toInt()}';
    _maxPriceController.text = '\$${filters.priceRange.end.toInt()}+';
  }

  Future<void> _selectDate() async {
    final filters = ref.read(searchControllerProvider).filters;
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CustomDateRangePicker(
        initialStartDate: filters.startDate,
        initialEndDate: filters.endDate,
        initialPickupTime: filters.pickupTime,
        initialDropTime: filters.dropTime,
      ),
    );
    
    if (result != null) {
      ref.read(searchControllerProvider.notifier).updateDateRange(
        startDate: result['startDate'] as DateTime?,
        endDate: result['endDate'] as DateTime?,
        pickupTime: result['pickupTime'] as TimeOfDay?,
        dropTime: result['dropTime'] as TimeOfDay?,
      );
    }
  }

  void _clearAllFilters() {
    ref.read(searchControllerProvider.notifier).clearAllFilters();
    final defaultFilters = ref.read(searchControllerProvider).filters;
    _minPriceController.text = '\$${defaultFilters.priceRange.start.toInt()}';
    _maxPriceController.text = '\$${defaultFilters.priceRange.end.toInt()}+';
    _locationController.text = 'Shore Dr, Chicago 0062 Usa';
    setState(() {
      _showAllColors = false;
    });
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day.toString().padLeft(2, '0')}, ${months[date.month - 1]}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final searchState = ref.watch(searchControllerProvider);
    final filterOptionsState = ref.watch(filterOptionsControllerProvider);
    final filters = searchState.filters;
    final options = filterOptionsState.options;

    // Update controllers based on current filters
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _minPriceController.text = '\$${filters.priceRange.start.toInt()}';
        _maxPriceController.text = '\$${filters.priceRange.end.toInt()}+';
        if (filters.location != null && filters.location!.isNotEmpty) {
          _locationController.text = filters.location!;
        }
      }
    });

    return Container(
      height: screenHeight * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.04,
              vertical: 16,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.close, size: 24, color: Colors.black),
                ),
                const Text(
                  'Filters',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 24), // Balance for close icon
              ],
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  // Type of Cars
                  _buildSectionTitle('Type of Cars'),
                  const SizedBox(height: 12),
                  _buildCarTypeOptions(options.carTypes, filters.selectedCarType),
                  const SizedBox(height: 24),
                  Divider(
                    color: Colors.grey[300],
                    thickness: 1,
                  ),
                  // Price range
                  _buildSectionTitle('Price range'),
                  const SizedBox(height: 12),
                  _buildPriceRangeSection(filters.priceRange),
                  const SizedBox(height: 30),
                  Divider(
                    color: Colors.grey[300],
                    thickness: 1,
                  ),
                  const SizedBox(height: 24),
                  // Rental Time
                  _buildSectionTitle('Rental Time'),
                  const SizedBox(height: 12),
                  _buildRentalTimeOptions(options.rentalTimes, filters.selectedRentalTime),
                  const SizedBox(height: 24),
                  // Pick up and Drop Date
                  _buildSectionTitle('Pick up and Drop Date'),
                  const SizedBox(height: 12),
                  _buildDatePicker(filters),
                  const SizedBox(height: 24),
                  // Car Location
                  _buildSectionTitle('Car Location'),
                  const SizedBox(height: 12),
                  _buildLocationInput(),
                  const SizedBox(height: 24),
                  // Colors
                  _buildColorsSection(options.colors, filters.selectedColor),
                  const SizedBox(height: 24),
                  // Seating Capacity
                  _buildSectionTitle('Siting Capacity'),
                  const SizedBox(height: 12),
                  _buildCapacityOptions(options.capacities, filters.selectedCapacity),
                  const SizedBox(height: 24),
                  // Fuel Type
                  _buildSectionTitle('Fuel Type'),
                  const SizedBox(height: 12),
                  _buildFuelTypeOptions(options.fuelTypes, filters.selectedFuelType),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          // Footer
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.04,
              vertical: 16,
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _clearAllFilters,
                  child: const Text(
                    'Clear All',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    ref.read(searchControllerProvider.notifier).updateLocation(
                      _locationController.text.isNotEmpty ? _locationController.text : null,
                    );
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C2C2C),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.15,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Show 100+ Cars',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
    );
  }

  Widget _buildCarTypeOptions(List<String> options, String? selectedCarType) {
    final currentSelected = selectedCarType ?? options.first;
    final selectedIndex = options.indexWhere((option) => option == currentSelected);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final containerWidth = constraints.maxWidth;
        final itemWidth = containerWidth / options.length;
        
        return Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Stack(
            children: [
              // Animated sliding indicator
              AnimatedPositioned(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOutCubic,
                left: selectedIndex >= 0 ? selectedIndex * itemWidth + 2 : 2,
                top: 2,
                bottom: 2,
                width: itemWidth - 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2C),
                    borderRadius: BorderRadius.circular(23),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              // Option buttons
              Row(
                children: options.map((option) {
                  final isSelected = currentSelected == option;
                  
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        ref.read(searchControllerProvider.notifier).updateCarType(option);
                      },
                      child: Container(
                        alignment: Alignment.center,
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 350),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : Colors.grey[700],
                          ),
                          child: Text(option),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPriceRangeSection(RangeValues priceRange) {
    return Column(
      children: [
        // Price histogram placeholder
        Container(
          height: 60,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            children: [
              // Simple bar representation
              Positioned.fill(
                child: Row(
                  children: List.generate(20, (index) {
                    final height = (20 - index % 5) * 2.0;
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          height: height,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C2C2C),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              // Range slider overlay
              RangeSlider(
                values: priceRange,
                min: 10,
                max: 230,
                divisions: 220,
                activeColor: const Color(0xFF2C2C2C),
                inactiveColor: Colors.transparent,
                onChanged: (values) {
                  ref.read(searchControllerProvider.notifier).updatePriceRange(values);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _updatePriceControllers();
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildPriceInput(
                controller: _minPriceController,
                label: 'Minimum',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPriceInput(
                controller: _maxPriceController,
                label: 'Maximum',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPriceInput({
    required TextEditingController controller,
    required String label,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRentalTimeOptions(List<String> options, String? selectedRentalTime) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: options.map((option) {
        final isSelected = selectedRentalTime == option;
        return GestureDetector(
          onTap: () {
            ref.read(searchControllerProvider.notifier).updateRentalTime(
              isSelected ? null : option,
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF2C2C2C) : Colors.grey[100],
              borderRadius: BorderRadius.circular(25),
            ),
            child: Text(
              option,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDatePicker(SearchFilters filters) {
    String dateText = '05, Jun, 2024';
    if (filters.startDate != null && filters.endDate != null) {
      dateText = '${_formatDate(filters.startDate!)} - ${_formatDate(filters.endDate!)}';
    } else if (filters.startDate != null) {
      dateText = _formatDate(filters.startDate!);
    }
    
    return GestureDetector(
      onTap: _selectDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.grey[600], size: 20),
                const SizedBox(width: 12),
                Text(
                  dateText,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Icon(Icons.keyboard_arrow_down, color: Colors.grey[600], size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on, color: Colors.grey[600], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _locationController,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorsSection(List<ColorOption> colors, String? selectedColor) {
    final displayedColors = _showAllColors ? colors : colors.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle('Colors'),
            if (colors.length > 4)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showAllColors = !_showAllColors;
                  });
                },
                child: Text(
                  _showAllColors ? 'Show Less' : 'See All',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: displayedColors.map((colorOption) {
            final isSelected = selectedColor == colorOption.name;
            return GestureDetector(
              onTap: () {
                ref.read(searchControllerProvider.notifier).updateColor(
                  isSelected ? null : colorOption.name,
                );
              },
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(colorOption.colorValue),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    colorOption.name,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCapacityOptions(List<String> options, String? selectedCapacity) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: options.map((option) {
        final isSelected = selectedCapacity == option;
        return GestureDetector(
          onTap: () {
            ref.read(searchControllerProvider.notifier).updateCapacity(
              isSelected ? null : option,
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF2C2C2C) : Colors.grey[100],
              borderRadius: BorderRadius.circular(25),
            ),
            child: Text(
              option,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFuelTypeOptions(List<String> options, String? selectedFuelType) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: options.map((option) {
        final isSelected = selectedFuelType == option;
        return GestureDetector(
          onTap: () {
            ref.read(searchControllerProvider.notifier).updateFuelType(
              isSelected ? null : option,
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF2C2C2C) : Colors.grey[100],
              borderRadius: BorderRadius.circular(25),
            ),
            child: Text(
              option,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

