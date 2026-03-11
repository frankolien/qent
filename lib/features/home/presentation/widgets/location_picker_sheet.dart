import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/features/home/presentation/providers/location_provider.dart';
import 'package:qent/features/search/domain/models/location.dart';

class LocationPickerSheet extends ConsumerStatefulWidget {
  const LocationPickerSheet({super.key});

  @override
  ConsumerState<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends ConsumerState<LocationPickerSheet> {
  final _searchController = TextEditingController();
  List<LocationModel> _searchResults = [];
  bool _isSearching = false;
  bool _isDetectingLocation = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _detectCurrentLocation() async {
    setState(() => _isDetectingLocation = true);
    try {
      final ds = ref.read(locationDataSourceProvider);
      final location = await ds.getCurrentLocationWithAddress();
      if (mounted) {
        ref.read(userLocationProvider.notifier).setLocation(location);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not detect location: ${e.toString().replaceFirst('Exception: ', '')}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isDetectingLocation = false);
      }
    }
  }

  Future<void> _searchLocations(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    try {
      final ds = ref.read(locationDataSourceProvider);
      final results = await ds.searchLocationsByName(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectLocation(LocationModel location) {
    ref.read(userLocationProvider.notifier).setLocation(location);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final popularLocations = LocationModel.getPopularLocations();
    final currentLocation = ref.watch(userLocationProvider).value;
    final showSearchResults = _searchController.text.trim().length >= 2;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Text(
              'Choose Location',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
                letterSpacing: -0.3,
              ),
            ),
          ),
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  Icon(Icons.search_rounded, color: Colors.grey[400], size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 14),
                      onChanged: _searchLocations,
                      decoration: InputDecoration(
                        hintText: 'Search city or area...',
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() {
                          _searchResults = [];
                          _isSearching = false;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Icon(Icons.close, size: 18, color: Colors.grey[500]),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Detect current location button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: GestureDetector(
              onTap: _isDetectingLocation ? null : _detectCurrentLocation,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F7FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    _isDetectingLocation
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF1976D2),
                            ),
                          )
                        : const Icon(Icons.my_location_rounded, size: 20, color: Color(0xFF1976D2)),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Use current location',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1976D2),
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Section header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              showSearchResults ? 'Search Results' : 'Popular Locations',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Location list
          Expanded(
            child: _isSearching
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A1A1A)),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: showSearchResults ? _searchResults.length : popularLocations.length,
                    itemBuilder: (context, index) {
                      final location = showSearchResults
                          ? _searchResults[index]
                          : popularLocations[index];
                      final isSelected = currentLocation?.city == location.city &&
                          currentLocation?.country == location.country;

                      return ListTile(
                        onTap: () => _selectLocation(location),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF1A1A1A)
                                : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.location_on_outlined,
                            size: 18,
                            color: isSelected ? Colors.white : Colors.grey[600],
                          ),
                        ),
                        title: Text(
                          location.city ?? location.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                        subtitle: Text(
                          '${location.state ?? ''}, ${location.country ?? 'Nigeria'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[400],
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, size: 20, color: Color(0xFF1A1A1A))
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
