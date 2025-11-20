import 'package:flutter/material.dart';
import 'package:my_plant/providers/auth_provider.dart';
import 'package:my_plant/providers/permission_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

class PermissionsSection extends StatefulWidget {
  const PermissionsSection({super.key});

  @override
  State<PermissionsSection> createState() => _PermissionsSectionState();
}

class _PermissionsSectionState extends State<PermissionsSection> {
  bool _isCheckingLocationService = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final isSeller = authProvider.userType == 'seller';

        final locationSubtitle = isSeller
            ? 'Required to set your store\'s coordinates accurately.'
            : 'Required to find nearby stores and plant sellers.';
        final cameraSubtitle = isSeller
            ? 'Required for uploading images of your store and plants.'
            : 'Required for the plant scanner and identification feature.';

        return Consumer<PermissionProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return const Center(
                  child: CircularProgressIndicator(color: Colors.white));
            }
            return Column(
              children: [
                _buildPermissionItem(
                  context: context,
                  title: 'Location',
                  subtitle: locationSubtitle,
                  status: provider.locationStatus,
                  onRequest: () => _handleLocationPermissionRequest(provider),
                  onOpenSettings: () => provider.openSettings(),
                  isCheckingService: _isCheckingLocationService,
                ),
                const Divider(color: Colors.white24),
                _buildPermissionItem(
                  context: context,
                  title: 'Camera',
                  subtitle: cameraSubtitle,
                  status: provider.cameraStatus,
                  onRequest: () => provider.requestCameraPermission(),
                  onOpenSettings: () => provider.openSettings(),
                  isCheckingService: false,
                ),
              ],
            );
          },
        );
      },
    );
  }

  // FIX: New method to handle location permission with location service check
  Future<void> _handleLocationPermissionRequest(
      PermissionProvider provider) async {
    setState(() => _isCheckingLocationService = true);

    await provider.requestLocationPermission();

    // Wait a moment to let the user enable location services
    await Future.delayed(const Duration(milliseconds: 1500));

    // Check if location services are now enabled
    final isServiceEnabled = await provider.isLocationServiceEnabled();

    if (mounted) {
      setState(() => _isCheckingLocationService = false);

      if (provider.isLocationGranted && !isServiceEnabled) {
        // Show a reminder if permission is granted but service is still off
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission granted! Please make sure location services are turned on in your device settings.',
            ),
            duration: Duration(seconds: 4),
            backgroundColor: Colors.orange,
          ),
        );
      } else if (provider.isLocationGranted && isServiceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission granted and services enabled!'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Widget _buildPermissionItem({
    required BuildContext context,
    required String title,
    required String subtitle,
    required PermissionStatus status,
    required VoidCallback onRequest,
    required VoidCallback onOpenSettings,
    required bool isCheckingService,
  }) {
    String statusText;
    Color statusColor;
    Widget actionButton;

    if (isCheckingService) {
      statusText = 'Checking...';
      statusColor = Colors.blueAccent;
      actionButton = const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white,
        ),
      );
    } else if (status.isGranted) {
      statusText = 'Granted';
      statusColor = Colors.greenAccent;
      actionButton = const Icon(Icons.check_circle, color: Colors.greenAccent);
    } else if (status.isPermanentlyDenied) {
      statusText = 'Permanently Denied';
      statusColor = Colors.redAccent;
      actionButton = ElevatedButton(
        onPressed: onOpenSettings,
        child: const Text('Open Settings'),
      );
    } else {
      statusText = 'Denied';
      statusColor = Colors.orangeAccent;
      actionButton = ElevatedButton(
        onPressed: onRequest,
        child: const Text('Grant Access'),
      );
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 4),
          Text(
            'Status: $statusText',
            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      trailing: actionButton,
    );
  }
}