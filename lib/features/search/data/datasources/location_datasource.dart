import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:qent/features/search/domain/models/location.dart';

/// Data source for location services
/// Handles GPS coordinates and reverse geocoding (coordinates to address)
class LocationDataSource {
  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Check location permissions
  Future<LocationPermission> checkLocationPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Request location permissions
  Future<LocationPermission> requestLocationPermission() async {
    return await Geolocator.requestPermission();
  }

  /// Get current position (GPS coordinates only)
  Future<Position> getCurrentPosition() async {
    bool serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await checkLocationPermission();
    if (permission == LocationPermission.denied) {
      permission = await requestLocationPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// Convert coordinates to address (Reverse Geocoding)
  /// This is what gives you the actual location name/address
  Future<LocationModel> getLocationFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    try {
      // Reverse geocoding: coordinates -> address
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isEmpty) {
        throw Exception('No address found for these coordinates');
      }

      final placemark = placemarks.first;

      return LocationModel(
        id: 'current-${DateTime.now().millisecondsSinceEpoch}',
        name: placemark.name ?? 'Current Location',
        address: _buildAddressString(placemark),
        latitude: latitude,
        longitude: longitude,
        city: placemark.locality ?? placemark.subLocality,
        state: placemark.administrativeArea,
        country: placemark.country ?? 'Nigeria',
        isCurrentLocation: true,
      );
    } catch (e) {
      throw Exception('Failed to get address from coordinates: $e');
    }
  }

  /// Get current location with address
  /// This combines GPS + Reverse Geocoding
  Future<LocationModel> getCurrentLocationWithAddress() async {
    // Step 1: Get GPS coordinates
    final position = await getCurrentPosition();

    // Step 2: Convert coordinates to address
    return await getLocationFromCoordinates(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  /// Convert address to coordinates (Forward Geocoding)
  /// Useful if you want to search by address name
  Future<List<LocationModel>> searchLocationsByName(String query) async {
    try {
      // Forward geocoding: address -> coordinates
      List<Location> locations = await locationFromAddress(query);

      return locations.map((location) {
        return LocationModel(
          id: 'search-${DateTime.now().millisecondsSinceEpoch}-${location.hashCode}',
          name: query,
          address: query,
          latitude: location.latitude,
          longitude: location.longitude,
          isCurrentLocation: false,
        );
      }).toList();
    } catch (e) {
      // If no results, return empty list
      return [];
    }
  }

  /// Build a formatted address string from placemark
  String _buildAddressString(Placemark placemark) {
    final parts = <String>[];
    
    // Build street address (avoid duplicates)
    final streetAddress = StringBuffer();
    if (placemark.subThoroughfare != null && placemark.subThoroughfare!.isNotEmpty) {
      streetAddress.write(placemark.subThoroughfare!);
    }
    if (placemark.thoroughfare != null && placemark.thoroughfare!.isNotEmpty) {
      if (streetAddress.isNotEmpty) {
        streetAddress.write(' ');
      }
      streetAddress.write(placemark.thoroughfare!);
    }
    // Use street if thoroughfare/subThoroughfare don't give us a good address
    if (streetAddress.isEmpty && placemark.street != null && placemark.street!.isNotEmpty) {
      streetAddress.write(placemark.street!);
    }
    
    if (streetAddress.isNotEmpty) {
      parts.add(streetAddress.toString());
    }
    
    // Add city/locality
    if (placemark.locality != null && placemark.locality!.isNotEmpty) {
      parts.add(placemark.locality!);
    } else if (placemark.subLocality != null && placemark.subLocality!.isNotEmpty) {
      parts.add(placemark.subLocality!);
    }
    
    // Add state/administrative area
    if (placemark.administrativeArea != null && placemark.administrativeArea!.isNotEmpty) {
      parts.add(placemark.administrativeArea!);
    }
    
    // Add country (optional, often redundant)
    // Only add country if it's not obvious from state/city
    // if (placemark.country != null && placemark.country!.isNotEmpty) {
    //   parts.add(placemark.country!);
    // }

    return parts.isNotEmpty ? parts.join(', ') : 'Current Location';
  }
}

