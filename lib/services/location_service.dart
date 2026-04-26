import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/cupertino.dart';

class LocationService extends GetxService {
  /// Get current location (latitude, longitude)
  /// Returns a map with 'latitude' and 'longitude' keys
  /// Returns null if location permission is not granted
  Future<Map<String, double>?> getCurrentLocation() async {
    try {
      // Check permission status
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        debugPrint("📍 [Location] Permission denied. Requesting permission...");
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint(
          "📍 [Location] Permission denied/forever. Location data unavailable.",
        );
        return null;
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        debugPrint("📍 [Location] Permission granted. Fetching location...");

        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );

        final location = {
          'latitude': position.latitude,
          'longitude': position.longitude,
        };

        debugPrint(
          "📍 [Location] Current position: ${position.latitude}, ${position.longitude}",
        );
        return location;
      }
    } catch (e) {
      debugPrint("❌ [Location] Error getting location: $e");
    }
    return null;
  }

  /// Get last known location (faster, doesn't require fresh GPS read)
  Future<Map<String, double>?> getLastKnownLocation() async {
    try {
      final position = await Geolocator.getLastKnownPosition();

      if (position == null) {
        debugPrint("📍 [Location] No last known position available.");
        return null;
      }

      final location = {
        'latitude': position.latitude,
        'longitude': position.longitude,
      };

      debugPrint(
        "📍 [Location] Last known position: ${position.latitude}, ${position.longitude}",
      );
      return location;
    } catch (e) {
      debugPrint("❌ [Location] Error getting last known position: $e");
      return null;
    }
  }
}

