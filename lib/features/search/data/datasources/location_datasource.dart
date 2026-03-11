import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:qent/features/search/domain/models/location.dart';

/// Data source for location services
/// Handles GPS coordinates and reverse geocoding (coordinates to address)
class LocationDataSource {
  void _log(String message) {
    if (kDebugMode) debugPrint('[Qent Location] $message');
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    _log('Location services enabled: $enabled');
    return enabled;
  }

  /// Check location permissions
  Future<LocationPermission> checkLocationPermission() async {
    final perm = await Geolocator.checkPermission();
    _log('Permission status: $perm');
    return perm;
  }

  /// Request location permissions
  Future<LocationPermission> requestLocationPermission() async {
    _log('> Requesting location permission');
    final perm = await Geolocator.requestPermission();
    _log('Permission result: $perm');
    return perm;
  }

  /// Get current position (GPS coordinates only)
  Future<Position> getCurrentPosition() async {
    _log('> Getting current GPS position');
    final sw = Stopwatch()..start();

    bool serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      _log('FAIL: Location services disabled');
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await checkLocationPermission();
    if (permission == LocationPermission.denied) {
      permission = await requestLocationPermission();
      if (permission == LocationPermission.denied) {
        _log('FAIL: Location permission denied');
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _log('FAIL: Location permission permanently denied');
      throw Exception(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
    sw.stop();
    _log('OK: GPS position: ${position.latitude}, ${position.longitude} (${sw.elapsedMilliseconds}ms)');
    return position;
  }

  /// Convert coordinates to address (Reverse Geocoding)
  Future<LocationModel> getLocationFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    _log('> Reverse geocoding: $latitude, $longitude');
    final sw = Stopwatch()..start();
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isEmpty) {
        _log('FAIL: No address found');
        throw Exception('No address found for these coordinates');
      }

      final placemark = placemarks.first;
      final location = LocationModel(
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
      sw.stop();
      _log('OK: Address: ${location.address} | city: ${location.city} (${sw.elapsedMilliseconds}ms)');
      return location;
    } catch (e) {
      sw.stop();
      _log('ERROR: Reverse geocoding failed (${sw.elapsedMilliseconds}ms): $e');
      throw Exception('Failed to get address from coordinates: $e');
    }
  }

  /// Get current location with address
  Future<LocationModel> getCurrentLocationWithAddress() async {
    _log('> Getting full location (GPS + address)');
    final sw = Stopwatch()..start();

    final position = await getCurrentPosition();
    final location = await getLocationFromCoordinates(
      latitude: position.latitude,
      longitude: position.longitude,
    );

    sw.stop();
    _log('OK: Full location resolved: ${location.address} (${sw.elapsedMilliseconds}ms total)');
    return location;
  }

  /// Convert address to coordinates (Forward Geocoding)
  Future<List<LocationModel>> searchLocationsByName(String query) async {
    _log('> Forward geocoding: "$query"');
    final sw = Stopwatch()..start();
    try {
      List<Location> locations = await locationFromAddress(query);
      sw.stop();

      final results = locations.map((location) {
        return LocationModel(
          id: 'search-${DateTime.now().millisecondsSinceEpoch}-${location.hashCode}',
          name: query,
          address: query,
          latitude: location.latitude,
          longitude: location.longitude,
          isCurrentLocation: false,
        );
      }).toList();

      _log('OK: Found ${results.length} results for "$query" (${sw.elapsedMilliseconds}ms)');
      return results;
    } catch (e) {
      sw.stop();
      _log('WARN: No results for "$query" (${sw.elapsedMilliseconds}ms): $e');
      return [];
    }
  }

  /// Build a formatted address string from placemark
  String _buildAddressString(Placemark placemark) {
    final parts = <String>[];

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
    if (streetAddress.isEmpty && placemark.street != null && placemark.street!.isNotEmpty) {
      streetAddress.write(placemark.street!);
    }

    if (streetAddress.isNotEmpty) {
      parts.add(streetAddress.toString());
    }

    if (placemark.locality != null && placemark.locality!.isNotEmpty) {
      parts.add(placemark.locality!);
    } else if (placemark.subLocality != null && placemark.subLocality!.isNotEmpty) {
      parts.add(placemark.subLocality!);
    }

    if (placemark.administrativeArea != null && placemark.administrativeArea!.isNotEmpty) {
      parts.add(placemark.administrativeArea!);
    }

    return parts.isNotEmpty ? parts.join(', ') : 'Current Location';
  }
}
