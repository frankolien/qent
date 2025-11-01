import 'package:flutter/material.dart';

class CustomDateRangePicker extends StatefulWidget {
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final TimeOfDay? initialPickupTime;
  final TimeOfDay? initialDropTime;

  const CustomDateRangePicker({
    super.key,
    this.initialStartDate,
    this.initialEndDate,
    this.initialPickupTime,
    this.initialDropTime,
  });

  @override
  State<CustomDateRangePicker> createState() => _CustomDateRangePickerState();
}

class _CustomDateRangePickerState extends State<CustomDateRangePicker> {
  late DateTime _currentMonth;
  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _pickupTime;
  TimeOfDay? _dropTime;

  @override
  void initState() {
    super.initState();
    _currentMonth = widget.initialStartDate ?? DateTime.now();
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
    _pickupTime = widget.initialPickupTime ?? const TimeOfDay(hour: 10, minute: 30);
    _dropTime = widget.initialDropTime ?? const TimeOfDay(hour: 17, minute: 30);
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  void _selectDate(DateTime date) {
    if (_startDate == null || (_startDate != null && _endDate != null)) {
      setState(() {
        _startDate = date;
        _endDate = null;
      });
    } else if (_endDate == null) {
      if (date.isBefore(_startDate!)) {
        setState(() {
          _endDate = _startDate;
          _startDate = date;
        });
      } else {
        setState(() {
          _endDate = date;
        });
      }
    }
  }

  bool _isInRange(DateTime date) {
    if (_startDate == null || _endDate == null) return false;
    return date.isAfter(_startDate!) && date.isBefore(_endDate!);
  }

  bool _isStartDate(DateTime date) {
    if (_startDate == null) return false;
    return date.year == _startDate!.year &&
        date.month == _startDate!.month &&
        date.day == _startDate!.day;
  }

  bool _isEndDate(DateTime date) {
    if (_endDate == null) return false;
    return date.year == _endDate!.year &&
        date.month == _endDate!.month &&
        date.day == _endDate!.day;
  }

  Future<void> _selectPickupTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _pickupTime ?? const TimeOfDay(hour: 10, minute: 30),
    );
    if (picked != null) {
      setState(() {
        _pickupTime = picked;
      });
    }
  }

  Future<void> _selectDropTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _dropTime ?? const TimeOfDay(hour: 17, minute: 30),
    );
    if (picked != null) {
      setState(() {
        _dropTime = picked;
      });
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'pm' : 'am';
    return '$hour : $minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    // Convert weekday to Sunday=0 format (weekday returns 1=Mon, 7=Sun)
    final firstDayWeekday = firstDayOfMonth.weekday % 7; // Sunday = 0, Monday = 1, ..., Saturday = 6
    final daysInMonth = lastDayOfMonth.day;
    
    final prevMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    final daysInPrevMonth = DateTime(prevMonth.year, prevMonth.month + 1, 0).day;
    
    final previousMonthDays = List.generate(firstDayWeekday, (index) {
      return daysInPrevMonth - firstDayWeekday + index + 1;
    });
    
    final currentMonthDays = List.generate(daysInMonth, (index) => index + 1);

    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    final weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Time Selection Section
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Time',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _selectPickupTime,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C2C2C),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.access_time, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Container(
                                width: 1,
                                height: 20,
                                color: Colors.white.withOpacity(0.3),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatTime(_pickupTime ?? const TimeOfDay(hour: 10, minute: 30)),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _selectDropTime,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.access_time, color: Colors.grey[600], size: 20),
                              const SizedBox(width: 8),
                              Container(
                                width: 1,
                                height: 20,
                                color: Colors.grey[400]!,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatTime(_dropTime ?? const TimeOfDay(hour: 17, minute: 30)),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Calendar Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _previousMonth,
                  icon: const Icon(Icons.chevron_left, color: Colors.black),
                ),
                Text(
                  '${months[_currentMonth.month - 1]} ${_currentMonth.year}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                IconButton(
                  onPressed: _nextMonth,
                  icon: const Icon(Icons.chevron_right, color: Colors.black),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Weekday Headers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: weekdays.map((day) {
                return Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Calendar Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: List.generate(6, (weekIndex) {
                return Row(
                  children: List.generate(7, (dayIndex) {
                    final dayPosition = weekIndex * 7 + dayIndex;
                    final isPrevMonth = dayPosition < previousMonthDays.length;
                    final isCurrentMonth = dayPosition >= previousMonthDays.length &&
                        dayPosition < previousMonthDays.length + currentMonthDays.length;
                    final isNextMonth = dayPosition >= previousMonthDays.length + currentMonthDays.length;
                    
                    DateTime date;
                    int day;
                    
                    if (isPrevMonth) {
                      day = previousMonthDays[dayPosition];
                      final prevMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
                      date = DateTime(prevMonth.year, prevMonth.month, day);
                    } else if (isCurrentMonth) {
                      day = currentMonthDays[dayPosition - previousMonthDays.length];
                      date = DateTime(_currentMonth.year, _currentMonth.month, day);
                    } else {
                      day = dayPosition - previousMonthDays.length - currentMonthDays.length + 1;
                      final nextMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
                      date = DateTime(nextMonth.year, nextMonth.month, day);
                    }
                    
                    final isStart = _isStartDate(date);
                    final isEnd = _isEndDate(date);
                    final isInRange = _isInRange(date);
                    final isToday = date.year == DateTime.now().year &&
                        date.month == DateTime.now().month &&
                        date.day == DateTime.now().day;
                    final isOtherMonth = isPrevMonth || isNextMonth;
                    
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: GestureDetector(
                          onTap: () => _selectDate(date),
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: isStart || isEnd
                                  ? const Color(0xFF2C2C2C)
                                  : isInRange
                                      ? Colors.grey[200]
                                      : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                day.toString().padLeft(2, '0'),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: (isStart || isEnd) ? FontWeight.bold : FontWeight.normal,
                                  color: (isStart || isEnd)
                                      ? Colors.white
                                      : isOtherMonth
                                          ? Colors.grey[300]
                                          : isToday
                                              ? Colors.blue
                                              : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              }),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop({
                        'startDate': _startDate,
                        'endDate': _endDate,
                        'pickupTime': _pickupTime,
                        'dropTime': _dropTime,
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C2C2C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
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
}

