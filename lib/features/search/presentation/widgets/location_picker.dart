import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:qent/features/search/data/datasources/location_datasource.dart';
import 'package:qent/features/search/domain/models/location.dart';

class LocationPicker extends ConsumerStatefulWidget {
  final String? initialLocation;
  final Function(LocationModel)? onLocationSelected;

  const LocationPicker({
    super.key,
    this.initialLocation,
    this.onLocationSelected,
  });

  @override
  ConsumerState<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends ConsumerState<LocationPicker> {
  final TextEditingController _searchController = TextEditingController();
  List<LocationModel> _filteredLocations = [];
  List<LocationModel> _recentLocations = []; // Will be loaded from Firebase
  final List<LocationModel> _popularLocations = LocationModel.getPopularLocations();
  bool _isSearching = false;
  bool _isLoadingCurrentLocation = false;
  LocationModel? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _filteredLocations = _popularLocations;
    final initialLocation = widget.initialLocation;
    if (initialLocation != null && initialLocation.isNotEmpty) {
      _searchController.text = initialLocation;
      // Try to find matching location
      final matched = _popularLocations.firstWhere(
        (loc) => loc.displayName.toLowerCase().contains(
          initialLocation.toLowerCase(),
        ),
        orElse: () => LocationModel(
          id: 'custom',
          name: initialLocation,
          address: initialLocation,
        ),
      );
      _selectedLocation = matched;
    }
    _loadRecentLocations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadRecentLocations() {
    // TODO: Load from Firebase/SharedPreferences
    // For now, use empty list
    setState(() {
      _recentLocations = [];
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _isSearching = query.isNotEmpty;
      
      if (query.isEmpty) {
        _filteredLocations = _popularLocations;
      } else {
        _filteredLocations = _popularLocations.where((location) {
          final searchLower = query.toLowerCase();
          return location.displayName.toLowerCase().contains(searchLower) ||
              (location.city != null && 
               location.city!.toLowerCase().contains(searchLower)) ||
              (location.state != null && 
               location.state!.toLowerCase().contains(searchLower));
        }).toList();
        
        // If no matches in popular locations, show custom location option
        if (_filteredLocations.isEmpty) {
          _filteredLocations = [
            LocationModel(
              id: 'custom-${DateTime.now().millisecondsSinceEpoch}',
              name: query,
              address: query,
            ),
          ];
        }
      }
    });
  }

  Future<void> _useCurrentLocation() async {
    if (_isLoadingCurrentLocation) {
      return;
    }

    setState(() {
      _isLoadingCurrentLocation = true;
    });

    try {
      final locationDataSource = LocationDataSource();
      
      final isEnabled = await locationDataSource.isLocationServiceEnabled();
      if (!isEnabled) {
        throw Exception(
          'Location services are disabled. Please enable location in your device settings.',
        );
      }

      var permission = await locationDataSource.checkLocationPermission();
      if (permission == LocationPermission.denied) {
        permission = await locationDataSource.requestLocationPermission();
        if (permission == LocationPermission.denied) {
          throw Exception(
            'Location permission denied. Please enable location permissions in app settings.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permissions are permanently denied. Please enable them in app settings.',
        );
      }

      // Get GPS coordinates and convert to address
      final currentLocation = await locationDataSource.getCurrentLocationWithAddress();

      if (mounted) {
        setState(() {
          _selectedLocation = currentLocation;
          _isLoadingCurrentLocation = false;
          _searchController.text = currentLocation.displayName;
        });

        widget.onLocationSelected?.call(currentLocation);
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location set: ${currentLocation.displayName}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCurrentLocation = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Could not get current location',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  e.toString().replaceAll('Exception: ', ''),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  void _selectLocation(LocationModel location) {
    setState(() {
      _selectedLocation = location;
      _searchController.text = location.displayName;
      _isSearching = false;
    });
    
    // TODO: Save to recent locations (Firebase/SharedPreferences)
    widget.onLocationSelected?.call(location);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.8,
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
                  'Select Location',
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
          // Search Bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Icon(Icons.search, color: Colors.grey[600], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search for a location...',
                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                      child: Icon(Icons.clear, color: Colors.grey[600], size: 20),
                    ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Current Location Button
          Padding(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
            child: GestureDetector(
              onTap: _isLoadingCurrentLocation ? null : _useCurrentLocation,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.my_location,
                      color: _isLoadingCurrentLocation ? Colors.grey : Colors.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isLoadingCurrentLocation
                          ? 'Getting location...'
                          : 'Use Current Location',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _isLoadingCurrentLocation ? Colors.grey : Colors.blue,
                      ),
                    ),
                    if (_isLoadingCurrentLocation) ...[
                      const SizedBox(width: 12),
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_recentLocations.isNotEmpty && !_isSearching) ...[
                    _buildSectionTitle('Recent Locations'),
                    const SizedBox(height: 12),
                    _buildLocationList(_recentLocations),
                    const SizedBox(height: 24),
                  ],
                  if (!_isSearching)
                    _buildSectionTitle('Popular Locations'),
                  if (_isSearching)
                    _buildSectionTitle('Search Results'),
                  const SizedBox(height: 12),
                  _buildLocationList(_filteredLocations),
                  const SizedBox(height: 24),
                ],
              ),
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
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
    );
  }

  Widget _buildLocationList(List<LocationModel> locations) {
    if (locations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(Icons.location_off, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No locations found',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: locations.map((location) {
        final isSelected = _selectedLocation?.id == location.id;
        return GestureDetector(
          onTap: () => _selectLocation(location),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue[50] : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.grey[200]!,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  location.isCurrentLocation
                      ? Icons.my_location
                      : Icons.location_on,
                  color: isSelected ? Colors.blue : Colors.grey[600],
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        location.displayName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.blue[900] : Colors.black87,
                        ),
                      ),
                      if (location.city != null || location.state != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          () {
                            if (location.city != null && location.state != null) {
                              return '${location.city}, ${location.state}';
                            } else if (location.city != null) {
                              return location.city!;
                            } else if (location.state != null) {
                              return location.state!;
                            }
                            return '';
                          }(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: Colors.blue,
                    size: 24,
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

