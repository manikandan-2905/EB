library;

import 'dart:async';
import 'dart:convert';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LocationService {
  /// Requests permissions if needed, then returns the current [Position].
  /// Throws a [LocationException] with a human-readable message on failure.
  static Future<Position> getCurrentPosition() async {
    // 1. Ensure the device has location services turned on
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationException(
        'Location services are disabled. Please enable GPS and try again.',
      );
    }

    // 2. Check existing permission
    LocationPermission permission = await Geolocator.checkPermission();

    // 3. Request if not yet granted
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationException(
          'Location permission denied. Please allow location access to save records.',
        );
      }
    }

    // 4. Permanently denied — guide user to app settings
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'Location permission is permanently denied. '
        'Please open App Settings → Permissions → Location and enable it.',
        isPermanentlyDenied: true,
      );
    }

    // 5. Fetch position with high accuracy and a 15-second timeout
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
    } on TimeoutException {
      throw const LocationException(
        'GPS timed out. Move to an open area and try again.',
      );
    } catch (e) {
      throw LocationException('Failed to get location: ${e.toString()}');
    }
  }

  /// Converts GPS coordinates into a detailed, human-readable address.
  /// (e.g. "12, Varatharajaperumal Street, Melapalayam, Tirunelveli - 627005")
  static Future<String> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    // Method 1: Try Native Android/iOS Geocoder via the geocoding package
    try {
      final geocoding = Geocoding();
      final placemarks = await geocoding
          .placemarkFromCoordinates(latitude, longitude)
          .timeout(const Duration(seconds: 6));

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = <String>[];

        // Door / Building name / number
        if (p.subThoroughfare != null && p.subThoroughfare!.isNotEmpty) {
          parts.add(p.subThoroughfare!);
        } else if (p.name != null &&
            p.name!.isNotEmpty &&
            p.name != p.street &&
            p.name != p.thoroughfare) {
          parts.add(p.name!);
        }

        // Street / Road (Thoroughfare)
        if (p.street != null && p.street!.isNotEmpty) {
          parts.add(p.street!);
        } else if (p.thoroughfare != null && p.thoroughfare!.isNotEmpty) {
          parts.add(p.thoroughfare!);
        }

        // Sublocality / Area / Ward
        if (p.subLocality != null &&
            p.subLocality!.isNotEmpty &&
            !parts.contains(p.subLocality)) {
          parts.add(p.subLocality!);
        }

        // Locality / City / Town
        if (p.locality != null &&
            p.locality!.isNotEmpty &&
            !parts.contains(p.locality)) {
          parts.add(p.locality!);
        }

        // SubAdministrativeArea (e.g. District like Tirunelveli)
        if (p.subAdministrativeArea != null &&
            p.subAdministrativeArea!.isNotEmpty &&
            !parts.contains(p.subAdministrativeArea)) {
          parts.add(p.subAdministrativeArea!);
        }

        // Postal Code (PIN code)
        if (p.postalCode != null && p.postalCode!.isNotEmpty) {
          parts.add(p.postalCode!);
        }

        final formatted =
            parts.where((part) => part.trim().isNotEmpty).join(', ');
        if (formatted.isNotEmpty) {
          return formatted;
        }
      }
    } catch (_) {
      // Fallback to Method 2 below if native geocoder is unavailable
    }

    // Method 2: OpenStreetMap Reverse Geocoding Fallback
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$latitude&lon=$longitude&accept-language=en',
      );
      final response = await http
          .get(uri, headers: {'User-Agent': 'EbWiremanApp/1.0'})
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;

        if (address != null) {
          final parts = <String>[];

          if (address['house_number'] != null) {
            parts.add(address['house_number'].toString());
          }
          if (address['road'] != null) {
            parts.add(address['road'].toString());
          }
          if (address['neighbourhood'] != null) {
            parts.add(address['neighbourhood'].toString());
          }
          if (address['suburb'] != null &&
              !parts.contains(address['suburb'].toString())) {
            parts.add(address['suburb'].toString());
          }

          final city = address['city'] ??
              address['town'] ??
              address['village'] ??
              address['municipality'];
          if (city != null && !parts.contains(city.toString())) {
            parts.add(city.toString());
          }

          final district = address['county'] ?? address['state_district'];
          if (district != null && !parts.contains(district.toString())) {
            parts.add(district.toString());
          }

          if (address['postcode'] != null) {
            parts.add(address['postcode'].toString());
          }

          final formatted =
              parts.where((part) => part.trim().isNotEmpty).join(', ');
          if (formatted.isNotEmpty) {
            return formatted;
          }
        }

        if (data['display_name'] != null) {
          return data['display_name'].toString();
        }
      }
    } catch (_) {
      // Ignore network fallback error and return coordinates
    }

    // Final fallback: Coordinates
    return 'Lat: ${latitude.toStringAsFixed(6)}, Lng: ${longitude.toStringAsFixed(6)}';
  }
}

/// Custom exception for location-related errors.
class LocationException implements Exception {
  final String message;
  final bool isPermanentlyDenied;

  const LocationException(this.message, {this.isPermanentlyDenied = false});

  @override
  String toString() => 'LocationException: $message';
}
