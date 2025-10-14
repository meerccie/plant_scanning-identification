import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

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

  Future<void> requestLocationPermission() async {
    _locationStatus = await Permission.location.request();
    notifyListeners();
  }

  Future<void> requestCameraPermission() async {
    _cameraStatus = await Permission.camera.request();
    notifyListeners();
  }

  Future<void> openSettings() async {
    await openAppSettings();
  }
}

