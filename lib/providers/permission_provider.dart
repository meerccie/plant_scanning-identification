import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

class PermissionProvider with ChangeNotifier {
  PermissionStatus _locationStatus = PermissionStatus.denied;
  PermissionStatus _cameraStatus = PermissionStatus.denied;
  bool _isLoading = true;

  PermissionStatus get locationStatus => _locationStatus;
  PermissionStatus get cameraStatus => _cameraStatus;
  bool get isLoading => _isLoading;

  bool get isLocationGranted => _locationStatus.isGranted;
  bool get isCameraGranted => _cameraStatus.isGranted;
  bool get areAllPermissionsGranted => isLocationGranted && isCameraGranted;

  PermissionProvider() {
    checkPermissions();
  }

  Future<void> checkPermissions() async {
    _isLoading = true;
    notifyListeners();
    _locationStatus = await Permission.location.status;
    _cameraStatus = await Permission.camera.status;
    _isLoading = false;
    notifyListeners();
  }

  // FIX: Enhanced to check and redirect to location services if needed
  Future<void> requestLocationPermission() async {
    // First, request the permission
    _locationStatus = await Permission.location.request();
    notifyListeners();
    
    // FIX: If permission is granted, check if location services are enabled
    if (_locationStatus.isGranted) {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Redirect user to enable location services
        await Geolocator.openLocationSettings();
      }
    }
  }

  Future<void> requestCameraPermission() async {
    _cameraStatus = await Permission.camera.request();
    notifyListeners();
  }

  Future<void> openSettings() async {
    await openAppSettings();
  }
  
  // FIX: Added helper method to check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }
}