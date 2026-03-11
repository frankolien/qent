import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/features/search/domain/models/filter_options.dart';
import 'package:qent/features/search/domain/models/search_filters.dart';
import 'package:qent/features/search/presentation/providers/search_providers.dart';
import 'package:qent/features/search/presentation/widgets/custom_date_range_picker.dart';
import 'package:qent/features/search/presentation/widgets/location_picker.dart';

class FilterBottomSheet extends ConsumerStatefulWidget {
  const FilterBottomSheet({super.key});

  @override
  ConsumerState<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends ConsumerState<FilterBottomSheet> {
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  bool _showAllColors = false;

  @override
  void initState() {
    super.initState();
    final filters = ref.read(searchControllerProvider).filters;
    _minPriceController.text = '₦${(filters.priceRange.start / 1000).toInt()}k';
    _maxPriceController.text = '₦${(filters.priceRange.end / 1000).toInt()}k+';
    if (filters.location != null && filters.location!.isNotEmpty) {
      _locationController.text = filters.location!;
    } else {
      _locationController.text = 'Shore Dr, Chicago 0062 Usa';
    }
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
    _minPriceController.text = '₦${(filters.priceRange.start / 1000).toInt()}k';
    _maxPriceController.text = '₦${(filters.priceRange.end / 1000).toInt()}k+';
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
    _minPriceController.text = '₦${(defaultFilters.priceRange.start / 1000).toInt()}k';
    _maxPriceController.text = '₦${(defaultFilters.priceRange.end / 1000).toInt()}k+';
    _locationController.text = 'Shore Dr, Chicago 0062 Usa';
    setState(() => _showAllColors = false);
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day.toString().padLeft(2, '0')},${months[date.month - 1]},${date.year}';
  }

  void _openLocationPicker() {
    final currentFilters = ref.read(searchControllerProvider).filters;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LocationPicker(
        initialLocation: _locationController.text.isNotEmpty
            ? _locationController.text
            : currentFilters.location,
        onLocationSelected: (location) {
          _locationController.text = location.displayName;
          ref.read(searchControllerProvider.notifier).updateLocation(location.displayName);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final searchState = ref.watch(searchControllerProvider);
    final filterOptionsState = ref.watch(filterOptionsControllerProvider);
    final filters = searchState.filters;
    final options = filterOptionsState.options;
    final filteredCars = ref.watch(filteredCarsProvider);

    return Container(
      height: screenHeight * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF1A1A1A)),
                  ),
                ),
                const Expanded(
                  child: Center(
                    child: Text('Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
                  ),
                ),
                const SizedBox(width: 36),
              ],
            ),
          ),
          // Content
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _buildSectionTitle('Type of Cars'),
                    const SizedBox(height: 14),
                    _buildCarTypeSelector(options.carTypes, filters.selectedCarType),
                    const SizedBox(height: 28),
                    _buildSectionTitle('Price range'),
                    const SizedBox(height: 14),
                    _buildPriceRange(filters.priceRange),
                    const SizedBox(height: 28),
                    _buildSectionTitle('Rental Time'),
                    const SizedBox(height: 14),
                    _buildChipRow(
                      options: options.rentalTimes,
                      selected: filters.selectedRentalTime,
                      onTap: (val) => ref.read(searchControllerProvider.notifier).updateRentalTime(filters.selectedRentalTime == val ? null : val),
                    ),
                    const SizedBox(height: 28),
                    _buildSectionTitle('Pick up and Drop Date'),
                    const SizedBox(height: 14),
                    _buildDatePicker(filters),
                    const SizedBox(height: 28),
                    _buildSectionTitle('Car Location'),
                    const SizedBox(height: 14),
                    _buildLocationInput(),
                    const SizedBox(height: 28),
                    _buildColorsSection(options.colors, filters.selectedColor),
                    const SizedBox(height: 28),
                    _buildSectionTitle('Siting Capacity'),
                    const SizedBox(height: 14),
                    _buildChipRow(
                      options: options.capacities,
                      selected: filters.selectedCapacity,
                      onTap: (val) => ref.read(searchControllerProvider.notifier).updateCapacity(filters.selectedCapacity == val ? null : val),
                    ),
                    const SizedBox(height: 28),
                    _buildSectionTitle('Fuel Type'),
                    const SizedBox(height: 14),
                    _buildChipRow(
                      options: options.fuelTypes,
                      selected: filters.selectedFuelType,
                      onTap: (val) => ref.read(searchControllerProvider.notifier).updateFuelType(filters.selectedFuelType == val ? null : val),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _clearAllFilters,
                    child: const Text('Clear All', style: TextStyle(fontSize: 15, color: Color(0xFF1A1A1A), fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        ref.read(searchControllerProvider.notifier).updateLocation(
                          _locationController.text.isNotEmpty ? _locationController.text : null,
                        );
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(26)),
                        child: Center(
                          child: filteredCars.when(
                            data: (cars) => Text('Show ${cars.length}+ Cars', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                            loading: () => const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                            error: (_, __) => const Text('Show Cars', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)));
  }

  Widget _buildCarTypeSelector(List<String> types, String? selected) {
    final current = selected ?? types.first;
    final selectedIndex = types.indexWhere((t) => t == current);

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth / types.length;
        return Container(
          height: 46,
          decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(23)),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                left: selectedIndex >= 0 ? selectedIndex * itemWidth + 3 : 3,
                top: 3,
                bottom: 3,
                width: itemWidth - 6,
                child: Container(decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(21))),
              ),
              Row(
                children: types.map((type) {
                  final isSelected = current == type;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => ref.read(searchControllerProvider.notifier).updateCarType(type),
                      child: Container(
                        alignment: Alignment.center,
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : Colors.grey[600]!),
                          child: Text(type),
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

  Widget _buildPriceRange(RangeValues priceRange) {
    return Column(
      children: [
        SizedBox(
          height: 50,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(20, (i) {
              final heights = [18, 28, 22, 38, 30, 42, 35, 48, 25, 40, 32, 45, 20, 36, 28, 50, 22, 34, 26, 44];
              final h = heights[i].toDouble();
              final barPos = 10000 + (190000 / 20) * i;
              final inRange = barPos >= priceRange.start && barPos <= priceRange.end;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  height: h,
                  decoration: BoxDecoration(color: inRange ? const Color(0xFF1A1A1A) : Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              );
            }),
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            activeTrackColor: const Color(0xFF1A1A1A),
            inactiveTrackColor: Colors.grey[300],
            thumbColor: Colors.white,
            overlayColor: const Color(0xFF1A1A1A).withValues(alpha: 0.1),
            rangeThumbShape: _CircleThumbShape(radius: 12),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
          ),
          child: RangeSlider(
            values: priceRange,
            min: 10000,
            max: 200000,
            divisions: 19,
            onChanged: (values) {
              ref.read(searchControllerProvider.notifier).updatePriceRange(values);
              WidgetsBinding.instance.addPostFrameCallback((_) => _updatePriceControllers());
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildPriceLabel('Minimum', _minPriceController),
            _buildPriceLabel('Maximum', _maxPriceController),
          ],
        ),
      ],
    );
  }

  Widget _buildPriceLabel(String label, TextEditingController controller) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Container(
          width: 80,
          height: 40,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey[300]!)),
          child: Center(
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A)),
              decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChipRow({required List<String> options, required String? selected, required void Function(String) onTap}) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((option) {
        final isSelected = selected == option;
        return GestureDetector(
          onTap: () => onTap(option),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            decoration: BoxDecoration(color: isSelected ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(23)),
            child: Text(option, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : Colors.grey[600])),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDatePicker(SearchFilters filters) {
    final today = DateTime.now();
    String dateText = _formatDate(today);
    if (filters.startDate != null && filters.endDate != null) {
      dateText = '${_formatDate(filters.startDate!)} - ${_formatDate(filters.endDate!)}';
    } else if (filters.startDate != null) {
      dateText = _formatDate(filters.startDate!);
    }

    return GestureDetector(
      onTap: _selectDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, color: Colors.grey[500], size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(dateText, style: TextStyle(fontSize: 13, color: filters.startDate != null ? const Color(0xFF1A1A1A) : Colors.grey[500], fontWeight: FontWeight.w500)),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey[500], size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationInput() {
    return GestureDetector(
      onTap: _openLocationPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Icon(Icons.location_on_outlined, color: Colors.grey[500], size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _locationController.text.isEmpty ? 'Select location' : _locationController.text,
                style: TextStyle(fontSize: 13, color: _locationController.text.isEmpty ? Colors.grey[400] : const Color(0xFF1A1A1A), fontWeight: FontWeight.w500),
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey[400], size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildColorsSection(List<ColorOption> colors, String? selectedColor) {
    final displayed = _showAllColors ? colors : colors.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle('Colors'),
            if (colors.length > 4)
              GestureDetector(
                onTap: () => setState(() => _showAllColors = !_showAllColors),
                child: Text(_showAllColors ? 'Show Less' : 'See All', style: const TextStyle(fontSize: 13, color: Color(0xFF2196F3), fontWeight: FontWeight.w500)),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: displayed.map((colorOpt) {
            final isSelected = selectedColor == colorOpt.name;
            final isWhite = colorOpt.colorValue == 0xFFFFFFFF;
            return Expanded(
              child: GestureDetector(
                onTap: () => ref.read(searchControllerProvider.notifier).updateColor(isSelected ? null : colorOpt.name),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(colorOpt.colorValue),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? const Color(0xFF2196F3) : isWhite ? Colors.grey[300]! : Colors.transparent,
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(colorOpt.name, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _CircleThumbShape extends RangeSliderThumbShape {
  final double radius;
  _CircleThumbShape({required this.radius});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => Size(radius * 2, radius * 2);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    bool isDiscrete = false,
    bool isEnabled = true,
    bool? isOnTop,
    required SliderThemeData sliderTheme,
    TextDirection? textDirection,
    Thumb? thumb,
    bool? isPressed,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(center + const Offset(0, 1), radius, Paint()..color = Colors.black.withValues(alpha: 0.1)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawCircle(center, radius, Paint()..color = Colors.white);
    canvas.drawCircle(center, radius, Paint()..color = Colors.grey[300]!..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }
}
