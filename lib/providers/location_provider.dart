// lib/providers/location_provider.dart
import 'dart:async'; // Added to fix TimeoutException error
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationProvider extends ChangeNotifier {
  Position? _currentPosition;
  bool _isLoading = false;
  String? _error;
  LocationPermission _permissionStatus = LocationPermission.unableToDetermine;

  Position? get currentPosition => _currentPosition;
  bool get isLoading => _isLoading;
  String? get error => _error;
  LocationPermission get permissionStatus => _permissionStatus;

  /// Enhanced method to get current location with better permission handling
  Future<bool> getCurrentLocation({BuildContext? context}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Step 1: Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _error = 'Please enable location services to find nearby stores.';
        if (context != null && context.mounted) {
          await _showLocationServiceDialog(context);
        }
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Step 2: Check current permission status
      _permissionStatus = await Geolocator.checkPermission();
      
      // Step 3: Handle permission states
      if (_permissionStatus == LocationPermission.denied) {
        _permissionStatus = await Geolocator.requestPermission();
        if (_permissionStatus == LocationPermission.denied) {
          _error = 'Location permission is required to find nearby stores.';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      if (_permissionStatus == LocationPermission.deniedForever) {
        _error = 'Location permissions are permanently denied. Please enable them in your device settings.';
        if (context != null && context.mounted) {
          await _showPermanentlyDeniedDialog(context);
        }
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // --- FIX ---
      // Replaced deprecated 'desiredAccuracy' and 'timeLimit'
      // with the new LocationSettings approach for better compatibility.
      _currentPosition = await Geolocator.getCurrentPosition(
        forceAndroidLocationManager: true, // Recommended for higher accuracy on Android
        timeLimit: const Duration(seconds: 15),
      );
      
      _error = null; // Clear previous errors
      _isLoading = false;
      notifyListeners();
      debugPrint('Location obtained: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}');
      return true;

    } on TimeoutException {
       _error = 'Could not get your location in time. Please try again.';
      _isLoading = false;
      notifyListeners();
      debugPrint('Location error: Timeout');
      return false;
    } catch (e) {
      _error = 'We couldn\'t get your location. Please try again.';
      _isLoading = false;
      notifyListeners();
      debugPrint('Location error: $e');
      return false;
    }
  }

  /// Show dialog when location services are disabled
  Future<void> _showLocationServiceDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Services Disabled'),
          content: const Text(
            'Please enable location services in your device settings to find nearby plant stores.',
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Open Settings'),
              onPressed: () async {
                Navigator.of(context).pop();
                await Geolocator.openLocationSettings();
              },
            ),
          ],
        );
      },
    );
  }

  /// Show dialog when permissions are permanently denied
  Future<void> _showPermanentlyDeniedDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permission Required'),
          content: const Text(
            'Location permission has been permanently denied. To use this feature, please go to your device settings and enable location for this app.',
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Open App Settings'),
              onPressed: () async {
                Navigator.of(context).pop();
                await Geolocator.openAppSettings();
              },
            ),
          ],
        );
      },
    );
  }

  /// Method to handle permission request with better UX
  Future<bool> requestLocationPermission({BuildContext? context}) async {
    try {
      // Check if services are enabled first
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (context != null && context.mounted) {
          await _showLocationServiceDialog(context);
        }
        return false;
      }

      // Check current permission
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        if (context != null && context.mounted) {
          await _showPermanentlyDeniedDialog(context);
        }
        return false;
      }

      _permissionStatus = permission;
      notifyListeners();
      
      return permission == LocationPermission.whileInUse || 
             permission == LocationPermission.always;
    } catch (e) {
      debugPrint('Error requesting location permission: $e');
      return false;
    }
  }

  /// Check if we have location permission without requesting
  Future<bool> hasLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      _permissionStatus = permission;
      return permission == LocationPermission.whileInUse || 
             permission == LocationPermission.always;
    } catch (e) {
      debugPrint('Error checking location permission: $e');
      return false;
    }
  }

  /// Get location with permission check (for use in scanning)
  Future<bool> getCurrentLocationForScanning({BuildContext? context}) async {
    return await getCurrentLocation(context: context);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearLocation() {
    _currentPosition = null;
    notifyListeners();
  }
}