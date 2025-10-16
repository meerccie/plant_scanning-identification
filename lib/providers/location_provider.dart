// lib/providers/location_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart'; // FIX: Added for debugPrint
import 'package:flutter/material.dart';      // FIX: Corrected the import path
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/services.dart';

class LocationProvider with ChangeNotifier {
  Position? _currentPosition;
  bool _isLoading = false;
  String? _error;
  LocationPermission _permissionStatus = LocationPermission.unableToDetermine;

  Position? get currentPosition => _currentPosition;
  bool get isLoading => _isLoading;
  String? get error => _error;
  LocationPermission get permissionStatus => _permissionStatus;

  Future<String?> getAddressFromCoordinates(double lat, double long) async {
    try {
      // FIX: Removed the non-existent 'localeIdentifier' parameter.
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, long);

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final addressParts = [
          place.name,
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
          place.country,
        ].where((part) => part != null && part.isNotEmpty).toList();

        if (addressParts.isEmpty) {
          return 'No address details found for this location.';
        }
        
        final uniqueParts = addressParts.toSet().toList();
        return uniqueParts.join(', ');
      } else {
        return 'No address found for these coordinates.';
      }
    } on PlatformException catch (e) {
      debugPrint('Geocoding PlatformException: ${e.message}');
      return 'Address lookup service is currently unavailable.';
    } catch (e) {
      debugPrint('Error getting address: $e');
      return 'Could not determine address due to an error.';
    }
  }

  Future<bool> getCurrentLocation({BuildContext? context}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
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

      _permissionStatus = await Geolocator.checkPermission();
      
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

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        forceAndroidLocationManager: true, 
        timeLimit: const Duration(seconds: 15),
      );
      
      _error = null;
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

  Future<bool> requestLocationPermission({BuildContext? context}) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (context != null && context.mounted) {
          await _showLocationServiceDialog(context);
        }
        return false;
      }

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